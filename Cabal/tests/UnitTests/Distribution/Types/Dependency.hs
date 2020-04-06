{-# OPTIONS_GHC -fno-warn-deprecations #-}   -- for importing "Distribution.Compat.Prelude.Internal"

module UnitTests.Distribution.Types.Dependency
    ( tests
    ) where

import Prelude ()
import Distribution.Compat.Prelude.Internal
import Distribution.Pretty
import Distribution.Types.Dependency
import Distribution.Types.LibraryName (LibraryName (LMainLibName))
import Distribution.Types.PackageName (mkPackageName)
import Distribution.Types.Version (mkVersion)
import Distribution.Types.VersionRange (majorBoundVersion)

import qualified Data.Set as Set
import Test.Tasty
import Test.Tasty.HUnit

tests :: [TestTree]
tests =
  [ testCase "Dependency pretty empty sublib set" dependencyPrettyEmptySublibSet
  , testCase "Dependency pretty LMainLibName sublib singleton" dependencyPrettyLMainLibNameSublib
  ]

dependencyPrettyEmptySublibSet :: Assertion
dependencyPrettyEmptySublibSet =
  assertEqual
  ":{} present when sublib set is empty"
  "base:{} ^>=4.13.0.0"
  (show (pretty baseDep))
  where
    baseDep = mkDependency
      (mkPackageName "base")
      (majorBoundVersion (mkVersion [4,13,0,0]))
      Set.empty

dependencyPrettyLMainLibNameSublib :: Assertion
dependencyPrettyLMainLibNameSublib =
  assertEqual
  ":{} absent when sublib set is [LMainLibName]"
  "base ^>=4.13.0.0"
  (show (pretty baseDep))
  where
    baseDep = mkDependency
      (mkPackageName "base")
      (majorBoundVersion (mkVersion [4,13,0,0]))
      (Set.singleton LMainLibName)
