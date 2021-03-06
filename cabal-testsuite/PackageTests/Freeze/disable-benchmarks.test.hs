import Test.Cabal.Prelude
main = cabalTest $ do
    withRepo "repo" . withSourceCopy $ do
        cabal "v1-freeze" ["--disable-benchmarks"]
        cwd <- fmap testCurrentDir getTestEnv
        assertFileDoesNotContain (cwd </> "cabal.config") "criterion"
