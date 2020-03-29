module Distribution.Types.CommonStanza.Lens (
    CommonStanza,
    module Distribution.Types.CommonStanza.Lens,
    ) where

import Distribution.Compat.Lens
import Distribution.Compat.Prelude
import Prelude ()

import Distribution.Types.BuildInfo           (BuildInfo)
import Distribution.Types.CommonStanza        (CommonStanza)
import Distribution.Types.CommonStanzaImports (CommonStanzaImports)
import Distribution.Types.UnqualComponentName (UnqualComponentName)

import qualified Distribution.Types.CommonStanza as T

commonStanzaName :: Lens' CommonStanza UnqualComponentName
commonStanzaName f s = fmap (\x -> s { T.commonStanzaName = x }) (f (T.commonStanzaName s))
{-# INLINE commonStanzaName #-}

commonStanzaRecursiveImports :: Lens' CommonStanza CommonStanzaImports
commonStanzaRecursiveImports f s = fmap (\x -> s { T.commonStanzaRecursiveImports = x }) (f (T.commonStanzaRecursiveImports s))
{-# INLINE commonStanzaRecursiveImports #-}


commonStanzaBuildInfo :: Lens' CommonStanza BuildInfo
commonStanzaBuildInfo f s = fmap (\x -> s { T.commonStanzaBuildInfo = x }) (f (T.commonStanzaBuildInfo s))
{-# INLINE commonStanzaBuildInfo #-}