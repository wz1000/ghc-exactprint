{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
-- | Use "runhaskell Setup.hs test" or "cabal test" to run these tests.
module Main where

-- import Language.Haskell.GHC.ExactPrint.Utils ( showGhc )
import qualified GHC.Paths
import Control.Monad
import System.Directory
import System.FilePath
import System.IO
import System.Exit

import Data.List
import qualified Data.Set as Set
import System.IO.Silently

import Test.Common
import Test.NoAnnotations
import Test.Transform

import Test.HUnit


-- import Debug.Trace

-- ---------------------------------------------------------------------

data GHCVersion = GHC92
           | GHC94
     deriving (Eq, Ord, Show)

ghcVersion :: GHCVersion
#if MIN_VERSION_ghc(9,4,0)
ghcVersion = GHC94
#else
ghcVersion = GHC92
#endif

-- | Directories to automatically find roundtrip tests
testDirs :: [FilePath]
testDirs =
  case ghcVersion of
    GHC92  -> ["ghc710", "ghc80", "ghc82", "ghc84", "ghc86", "ghc88", "ghc810", "ghc90", "ghc92"]
    GHC94  -> ["ghc710", "ghc80", "ghc82", "ghc84", "ghc86", "ghc88", "ghc810", "ghc90", "ghc92", "ghc94"]
    -- GHC94  -> ["ghc94"]

-- ---------------------------------------------------------------------

main :: IO ()
main = hSilence [stderr] $ do
  print ghcVersion
  tests <- mkTests
  cnts <- fst <$> runTestText (putTextToHandle stdout True) tests
  putStrLn $ show cnts
  if errors cnts > 0 || failures cnts > 0
     then exitFailure
     else return () -- exitSuccess

transform :: IO ()
transform = hSilence [stderr] $ do
  let libdir = GHC.Paths.libdir
  cnts <- fst <$> runTestText (putTextToHandle stdout True) (transformTestsTT libdir)
  putStrLn $ show cnts
  if errors cnts > 0 || failures cnts > 0
     then exitFailure
     else return () -- exitSuccess

-- ---------------------------------------------------------------------

findTests :: LibDir -> IO Test
findTests libdir
  = testList "Round-trip tests" <$> mapM (findTestsDir id (mkParserTest libdir)) testDirs

findTestsBC :: LibDir -> IO Test
findTestsBC libdir
  = testList "Balance comments tests" <$> mapM (findTestsDir filterBC (mkParserTestBC libdir)) testDirs

-- | Filter out tests that are known to fail, for particular compilers
filterBC :: [FilePath] -> [FilePath]
filterBC fps = sort $ Set.toList $ Set.difference (Set.fromList fps) skipped
-- filterBC fps = error $ "filterBC:fps=" ++ show fps
  where
  skipped = Set.fromList
    [
    "Control.hs",
    "Internals.hs",
    "LinePragma.hs",
    "QuasiQuote.hs",
    "RandomPGC.hs",
    "HashTab.hs",
    "LinePragmas.hs",

    -- All related to blending in CPP-as-comments
    "Cpp.hs",
    "Checkpoint.hs",
    "CommentPlacement6.hs"
    ]

findTestsMD :: LibDir -> IO Test
findTestsMD libdir
  = testList "Make Delta tests" <$> mapM (findTestsDir id (mkParserTestMD libdir)) testDirs

findPrettyTests :: LibDir -> IO Test
findPrettyTests libdir =
  testList "Default Annotations round-trip tests"
           <$> mapM (findTestsDir filterPrettyRoundTrip (mkPrettyRoundtrip libdir)) testDirs

-- | Filter out tests that are known to fail, for particular compilers
filterPrettyRoundTrip :: [FilePath] -> [FilePath]
filterPrettyRoundTrip fps = sort $ Set.toList $ Set.difference (Set.fromList fps) skipped
-- filterPrettyRoundTrip fps = error $ "filterPrettyRoundTrip:fps=" ++ show fps
  where
  skipped = Set.empty

findTestsDir :: ([FilePath] -> [FilePath]) -> (FilePath -> FilePath -> Test) -> FilePath -> IO Test
findTestsDir filterFn mkTestFn dir = do
  let fp = testPrefix </> dir
  fs <- getDirectoryContents fp
  let testFiles = sort $ filter (".hs" `isSuffixOf`) fs
  return $ testList dir (map (\fn -> TestLabel fn (mkTestFn dir fn)) $ filterFn testFiles)

listTests :: IO ()
listTests = do
  let
    ftd dir = do
      let fp = testPrefix </> dir
      fs <- getDirectoryContents fp
      let testFiles = sort $ filter (".hs" `isSuffixOf`) fs
      return (zip [0::Integer ..] testFiles)
  files <- mapM ftd testDirs
  putStrLn $ "round trip tests:" ++ show (zip testDirs files)

mkTests :: IO Test
mkTests = do
  -- listTests
  let libdir = GHC.Paths.libdir
  roundTripTests <- findTests libdir
  roundTripBalanceCommentsTests <- findTestsBC libdir
  roundTripMakeDeltaTests <- findTestsMD libdir
  -- prettyRoundTripTests <- findPrettyTests libdir
  return $ TestList [
                      internalTests,
                      roundTripTests
                    ,
                      (transformTests libdir)
                    , (failingTests libdir)
                    ,
                      roundTripBalanceCommentsTests
                    ,
                      roundTripMakeDeltaTests
                    ]

-- Tests that are no longer needed
                    -- , noAnnotationTests
                    -- ,
                    --   prettyRoundTripTests
                    -- ,

failingTests :: LibDir -> Test
failingTests libdir = testList "Failing tests"
  [
  -- Tests requiring future GHC modifications

  -- We do not capture EOF location very well any more
    mkTestModBad libdir "T10970a.hs"
  ]


mkParserTest :: LibDir -> FilePath -> FilePath -> Test
mkParserTest libdir dir fp = mkParsingTest (roundTripTest libdir) dir fp

mkParserTestBC :: LibDir -> FilePath -> FilePath -> Test
mkParserTestBC libdir dir fp = mkParsingTest (roundTripTestBC libdir) dir fp

mkParserTestMD :: LibDir -> FilePath -> FilePath -> Test
mkParserTestMD libdir dir fp = mkParsingTest (roundTripTestMD libdir) dir fp

-- ---------------------------------------------------------------------

formatTT :: ([([Char], Bool)], [([Char], Bool)]) -> IO ()
formatTT (ts, fs) = do
  when (not . null $ tail ts) (do
    putStrLn "Pass"
    mapM_ (putStrLn . fst) (tail ts)
    )
  when (not . null $ fs) (do
    putStrLn "Fail"
    mapM_ (putStrLn . fst) fs)

tr :: IO (Counts,Int)
tr = hSilence [stderr] $ do
  let libdir = GHC.Paths.libdir
  prettyRoundTripTests <- findPrettyTests libdir
  runTestText (putTextToHandle stdout True) prettyRoundTripTests

tt' :: IO (Counts,Int)
tt' = do
  let libdir = GHC.Paths.libdir
  runTestText (putTextToHandle stdout True) $ TestList [

    -- mkTestModChange libdir rmDecl7 "RmDecl7.hs"

    -- mkTestModChange libdir changeLocalDecls  "LocalDecls.hs"
    -- mkTestModChange libdir changeLayoutLet2 "LayoutLet2.hs"
    -- mkTestModChange libdir addLocaLDecl5  "AddLocalDecl5.hs"

   -- mkTestModChange libdir rmDecl1 "RmDecl1.hs"

   -- mkTestModChange libdir rmDecl4 "RmDecl4.hs"
    -- mkParserTestMD libdir      "ghc92" "Foo.hs"
    -- mkParserTest libdir      "ghc92" "Foo.hs"
    -- mkParserTestMD libdir      "ghc92" "Foo.hs"
    -- mkParserTest libdir      "ghc92" "Foo2.hs"
    -- mkParserTest libdir      "ghc710" "EmptyMostly.hs"
    -- mkParserTestBC libdir "ghc710" "Control.hs"
    -- mkParserTestBC libdir "ghc92" "CommentPlacement3.hs"
    -- mkParserTestBC libdir "ghc92" "TopLevelSemis.hs"

    -- mkParserTest libdir      "ghc92" "ConstructorComment.hs"
    -- mkParserTest libdir      "ghc92" "Binary.hs"
    -- mkParserTest libdir      "ghc92" "Observer.hs"
    -- mkParserTest libdir      "ghc92" "Observer1.hs"

   -- mkTestModChange libdir addLocaLDecl1  "AddLocalDecl1.hs"
   -- mkTestModChange libdir addLocaLDecl3  "AddLocalDecl3.hs"

    -- mkParserTestBC libdir "ghc710" "MultiParamTypeClasses.hs"

    -- mkParserTestBC libdir "ghc710" "DataFamilies.hs"
    -- mkParserTestBC libdir "ghc710" "Cpp.hs"
    -- mkParserTestBC libdir "ghc80" "T4139.hs"

    -- mkParserTestBC libdir "ghc92" "Checkpoint.hs"

    -- mkParserTestBC libdir "ghc92" "CommentPlacement6.hs"
    -- mkParserTest libdir "ghc92" "CommentPlacement6.hs"

    -- mkParserTest libdir "ghc92" "TopLevelSemis.hs"
    -- mkParserTestBC libdir "ghc92" "TopLevelSemis.hs"
    -- mkParserTestMD libdir "ghc92" "TopLevelSemis.hs"

    -- mkParserTest libdir "ghc92" "TopLevelSemis1.hs"
    -- mkParserTestBC libdir "ghc92" "TopLevelSemis1.hs"
    -- mkParserTestMD libdir "ghc92" "TopLevelSemis1.hs"

    mkParserTest libdir "ghc94" "HsDocTy.hs"

   -- Needs GHC changes


    ]

testsTT :: LibDir -> Test
testsTT libdir = TestList
  [
    mkParserTest libdir "ghc710" "Cpp.hs"
  , mkParserTest libdir "ghc710" "DroppedDoSpace.hs"
  ]

tt :: IO ()
-- tt = hSilence [stderr] $ do
tt = do
  let libdir = GHC.Paths.libdir
  cnts <- fst <$> runTestText (putTextToHandle stdout True) (testsTT libdir)
  putStrLn $ show cnts
  if errors cnts > 0 || failures cnts > 0
     then exitFailure
     else return () -- exitSuccess

-- ---------------------------------------------------------------------

ii :: IO ()
ii = do
  cnts <- fst <$> runTestText (putTextToHandle stdout True) internalTests
  putStrLn $ show cnts
  if errors cnts > 0 || failures cnts > 0
     then exitFailure
     else return () -- exitSuccess

internalTests :: Test
internalTests = testList "Internal tests"
  [
    -- testCleanupOneLine
  ]

{-
testCleanupOneLine :: Test
testCleanupOneLine = do
  let
    makeCase n = (show n
                 ,(T.replicate n " ") <> "\t|" <> T.replicate n " " <> "\t"
                 ,(T.replicate 8 " " <> "|"))
    mkTest n = TestCase $ assertEqual name outp (cleanupOneLine inp)
      where (name,inp,outp) = makeCase n
  testList "cleanupOneLine" $ map mkTest [1..7]
-}

-- ---------------------------------------------------------------------

pwd :: IO FilePath
pwd = getCurrentDirectory

cd :: FilePath -> IO ()
cd = setCurrentDirectory
