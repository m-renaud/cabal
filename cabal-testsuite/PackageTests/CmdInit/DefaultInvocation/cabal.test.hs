import Test.Cabal.Prelude

main = cabalTest $ do
    cabal "init" []
    cabal "v2-build" [":all"]
