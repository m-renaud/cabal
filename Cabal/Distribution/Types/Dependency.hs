{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}
module Distribution.Types.Dependency
  ( Dependency(..)
  , mkDependency
  , depPkgName
  , depVerRange
  , depLibraries
  , thisPackageVersion
  , notThisPackageVersion
  , simplifyDependency
  ) where

import Distribution.Compat.Prelude
import Prelude ()

import Distribution.Version
       (VersionRange, anyVersion, notThisVersion, simplifyVersionRange, thisVersion)

import Distribution.CabalSpecVersion
import Distribution.Compat.CharParsing        (char, spaces)
import Distribution.Compat.Parsing            (between, option)
import Distribution.FieldGrammar.Described
import Distribution.Parsec
import Distribution.Pretty
import Distribution.Types.LibraryName
import Distribution.Types.PackageId
import Distribution.Types.PackageName
import Distribution.Types.UnqualComponentName
import Text.PrettyPrint                       ((<+>))

import qualified Data.Set         as Set
import qualified Text.PrettyPrint as PP

-- | Describes a dependency on a source package (API)
--
-- /Invariant:/ package name does not appear as 'LSubLibName' in
-- set of library names.
--
data Dependency = Dependency
                    PackageName
                    VersionRange
                    (Set LibraryName)
                    -- ^ The set of libraries required from the package.
                    -- Only the selected libraries will be built.
                    -- It does not affect the cabal-install solver yet.
                  deriving (Generic, Read, Show, Eq, Typeable, Data)

depPkgName :: Dependency -> PackageName
depPkgName (Dependency pn _ _) = pn

depVerRange :: Dependency -> VersionRange
depVerRange (Dependency _ vr _) = vr

depLibraries :: Dependency -> Set LibraryName
depLibraries (Dependency _ _ cs) = cs

-- | Smart constructor of 'Dependency'.
--
-- If 'PackageName' is appears as 'LSubLibName' in a set of sublibraries,
-- it is automatically converted to 'LMainLibName'.
--
-- @since 3.4.0.0
--
mkDependency :: PackageName -> VersionRange -> Set LibraryName -> Dependency
mkDependency pn vr lb = Dependency pn vr (Set.map conv lb)
  where
    pn' = packageNameToUnqualComponentName pn

    conv l@LMainLibName                 = l
    conv l@(LSubLibName ln) | ln == pn' = LMainLibName
                            | otherwise = l

instance Binary Dependency
instance Structured Dependency
instance NFData Dependency where rnf = genericRnf

instance Pretty Dependency where
    pretty (Dependency name ver sublibs) = withSubLibs (pretty name) <+> pretty ver
      where
        withSubLibs doc
            | sublibs == mainLib = doc
            | otherwise          =
                doc <<>> if Set.toList sublibs == [LMainLibName]
                         then PP.empty
                         else PP.colon <<>> PP.braces prettySublibs

        prettySublibs = PP.hsep $ PP.punctuate PP.comma $ prettySublib <$> Set.toList sublibs

        prettySublib LMainLibName     = PP.text $ unPackageName name
        prettySublib (LSubLibName un) = PP.text $ unUnqualComponentName un

-- |
--
-- >>> simpleParsec "mylib:sub" :: Maybe Dependency
-- Just (Dependency (PackageName "mylib") AnyVersion (fromList [LSubLibName (UnqualComponentName "sub")]))
--
-- >>> simpleParsec "mylib:{sub1,sub2}" :: Maybe Dependency
-- Just (Dependency (PackageName "mylib") AnyVersion (fromList [LSubLibName (UnqualComponentName "sub1"),LSubLibName (UnqualComponentName "sub2")]))
--
-- >>> simpleParsec "mylib:{ sub1 , sub2 }" :: Maybe Dependency
-- Just (Dependency (PackageName "mylib") AnyVersion (fromList [LSubLibName (UnqualComponentName "sub1"),LSubLibName (UnqualComponentName "sub2")]))
--
-- >>> simpleParsec "mylib:{ sub1 , sub2 } ^>= 42" :: Maybe Dependency
-- Just (Dependency (PackageName "mylib") (MajorBoundVersion (mkVersion [42])) (fromList [LSubLibName (UnqualComponentName "sub1"),LSubLibName (UnqualComponentName "sub2")]))
--
-- >>> simpleParsec "mylib:{ } ^>= 42" :: Maybe Dependency
-- Just (Dependency (PackageName "mylib") (MajorBoundVersion (mkVersion [42])) (fromList []))
--
-- >>> traverse_ print (map simpleParsec ["mylib:mylib", "mylib:{mylib}", "mylib:{mylib,sublib}" ] :: [Maybe Dependency])
-- Just (Dependency (PackageName "mylib") AnyVersion (fromList [LMainLibName]))
-- Just (Dependency (PackageName "mylib") AnyVersion (fromList [LMainLibName]))
-- Just (Dependency (PackageName "mylib") AnyVersion (fromList [LMainLibName,LSubLibName (UnqualComponentName "sublib")]))
--
-- Spaces around colon are not allowed:
--
-- >>> map simpleParsec ["mylib: sub", "mylib :sub", "mylib: {sub1,sub2}", "mylib :{sub1,sub2}"] :: [Maybe Dependency]
-- [Nothing,Nothing,Nothing,Nothing]
--
-- Sublibrary syntax is accepted since @cabal-version: 3.0@
--
-- >>> map (`simpleParsec'` "mylib:sub") [CabalSpecV2_4, CabalSpecV3_0] :: [Maybe Dependency]
-- [Nothing,Just (Dependency (PackageName "mylib") AnyVersion (fromList [LSubLibName (UnqualComponentName "sub")]))]
--
instance Parsec Dependency where
    parsec = do
        name <- parsec

        libs <- option mainLib $ do
          _ <- char ':'
          versionGuardMultilibs
          parsecWarning PWTExperimental "colon specifier is experimental feature (issue #5660)"
          Set.singleton <$> parseLib <|> parseMultipleLibs

        spaces -- https://github.com/haskell/cabal/issues/5846

        ver  <- parsec <|> pure anyVersion
        return $ mkDependency name ver libs
      where
        parseLib          = LSubLibName <$> parsec
        parseMultipleLibs = between
            (char '{' *> spaces)
            (spaces *> char '}')
            (Set.fromList <$> parsecCommaList parseLib)

versionGuardMultilibs :: CabalParsing m => m ()
versionGuardMultilibs = do
  csv <- askCabalSpecVersion
  when (csv < CabalSpecV3_0) $ fail $ unwords
    [ "Sublibrary dependency syntax used."
    , "To use this syntax the package needs to specify at least 'cabal-version: 3.0'."
    , "Alternatively, if you are depending on an internal library, you can write"
    , "directly the library name as it were a package."
    ]

-- | Library set with main library.
mainLib :: Set LibraryName
mainLib = Set.singleton LMainLibName

instance Described Dependency where
    describe _ = REAppend
        [ RENamed "pkg-name" (describe (Proxy :: Proxy PackageName))
        , REOpt $ 
               reChar ':'
            <> REUnion
                [ reUnqualComponent
                , REAppend
                    [ reChar '{'
                    , RESpaces
                    -- no leading or trailing comma
                    , REMunch reSpacedComma reUnqualComponent
                    , RESpaces
                    , reChar '}'
                    ] 
                ]
        -- TODO: RESpaces1 should be just RESpaces, but we are able
        -- to generate non-parseable strings without mandatory space
        --
        -- https://github.com/haskell/cabal/issues/6589
        --
        , REOpt $ RESpaces1 <> vr
        ]
      where
        vr = RENamed "version-range" (describe (Proxy :: Proxy VersionRange))

-- mempty should never be in a Dependency-as-dependency.
-- This is only here until the Dependency-as-constraint problem is solved #5570.
-- Same for below.
--
-- Note: parser allows for empty set!
--
thisPackageVersion :: PackageIdentifier -> Dependency
thisPackageVersion (PackageIdentifier n v) =
  Dependency n (thisVersion v) Set.empty

notThisPackageVersion :: PackageIdentifier -> Dependency
notThisPackageVersion (PackageIdentifier n v) =
  Dependency n (notThisVersion v) Set.empty

-- | Simplify the 'VersionRange' expression in a 'Dependency'.
-- See 'simplifyVersionRange'.
--
simplifyDependency :: Dependency -> Dependency
simplifyDependency (Dependency name range comps) =
  Dependency name (simplifyVersionRange range) comps
