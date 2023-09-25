-- Copyright 2023 Lennart Augustsson
-- See LICENSE file for full license.
-- Functions for GHC that are defined in the UHS libs.
module Compat(module Compat) where
--import Control.Exception
import qualified Data.Function as F
import Data.Time
import Data.Time.Clock.POSIX
import qualified Control.Monad as M
import Control.Exception
import Data.List
import System.Environment
import System.IO
import GHC.Types(Any)

-- Functions needed for ghc
eqChar :: Char -> Char -> Bool
eqChar = (==)

neChar :: Char -> Char -> Bool
neChar = (/=)

ltChar :: Char -> Char -> Bool
ltChar = (<)

eqString :: String -> String -> Bool
eqString = (==)

leString :: String -> String -> Bool
leString = (<=)

readInt :: String -> Int
readInt = read

readDouble :: String -> Double
readDouble = read

showInt :: Int -> String
showInt = show

showDouble :: Double -> String
showDouble = show

showChar :: Char -> String
showChar = show

showBool :: Bool -> String
showBool = show

showUnit :: () -> String
showUnit = show

showString :: String -> String
showString = show

showList :: (a -> String) -> [a] -> String
showList sa arg =
  let
    showRest as =
      case as of
        [] -> "]"
        x : xs -> "," ++ sa x ++ showRest xs
  in
    case arg of
      [] -> "[]"
      a : as -> "[" ++ sa a ++ showRest as

showMaybe :: (a -> String) -> Maybe a -> String
showMaybe fa arg =
  case arg of
    Nothing -> "Nothing"
    Just a  -> "(Just " ++ fa a ++ ")"

elemBy :: (a -> a -> Bool) -> a -> [a] -> Bool
elemBy eq a = any (eq a)

stripPrefixBy :: (a -> a -> Bool) -> [a] -> [a] -> Maybe [a]
stripPrefixBy eq p s =
  case p of
    [] -> Just s
    c : cs ->
      case s of
        [] -> Nothing
        d : ds ->
          if eq c d then
            stripPrefixBy eq cs ds
          else
            Nothing

lookupBy :: (a -> a -> Bool) -> a -> [(a, b)] -> Maybe b
lookupBy eq x xys = fmap snd (find (eq x . fst) xys)

pair :: a -> b -> (a, b)
pair = (,)

eqList :: (a -> a -> Bool) -> [a] -> [a] -> Bool
eqList eq axs ays =
  case axs of
    [] ->
      case ays of
        [] -> True
        _:_ -> False
    x:xs ->
      case ays of
        [] -> False
        y:ys -> eq x y && eqList eq xs ys

eqPair :: (a -> a -> Bool) -> (b -> b -> Bool) -> (a, b) -> (a, b) -> Bool
eqPair eqa eqb ab1 ab2 =
  case ab1 of
    (a1, b1) ->
      case ab2 of
        (a2, b2) ->
          eqa a1 a2 && eqb b1 b2

showPair :: (a -> String) -> (b -> String) -> (a, b) -> String
showPair f g (a, b) = "(" ++ f a ++ "," ++ g b ++ ")"

eqInt :: Int -> Int -> Bool
eqInt = (==)

openFileM :: FilePath -> IOMode -> IO (Maybe Handle)
openFileM path m = do
  r <- (try $ openFile path m) :: IO (Either IOError Handle)
  case r of
    Left _ -> return Nothing
    Right h -> return (Just h)

when :: Bool -> IO () -> IO ()
when = M.when

on :: (a -> a -> b) -> (c -> a) -> (c -> c -> b)
on = F.on

getTimeMilli :: IO Int
getTimeMilli  = floor . (1000 *) . nominalDiffTimeToSeconds . utcTimeToPOSIXSeconds <$> getCurrentTime

padLeft :: Int -> String -> String
padLeft n s = replicate (n - length s) ' ' ++ s

spanUntil :: forall a . (a -> Bool) -> [a] -> ([a], [a])
spanUntil p =
  let
    rec r [] = (reverse r, [])
    rec r (x:xs) = if p x then rec (x:r) xs else (reverse (x:r), xs)
  in rec []

-- A hack until we have a real withArgs
withDropArgs :: Int -> IO a -> IO a
withDropArgs i ioa = do
  as <- getArgs
  withArgs (drop i as) ioa

-- A simple "quicksort" for now.
sortLE :: forall a . (a -> a -> Bool) -> [a] -> [a]
sortLE _  [] = []
sortLE le (x:xs) = sortLE le lt ++ (x : sortLE le ge)
  where (ge, lt) = partition (le x) xs

deleteAllBy :: forall a . (a -> a -> Bool) -> a -> [a] -> [a]
deleteAllBy _ _ [] = []
deleteAllBy eq x (y:ys) = if eq x y then deleteAllBy eq x ys else y : deleteAllBy eq x ys

deleteAllsBy :: forall a . (a -> a -> Bool) -> [a] -> [a] -> [a]
deleteAllsBy eq = foldl (flip (deleteAllBy eq))

forceString :: String -> ()
forceString [] = ()
forceString (c:cs) = c `seq` forceString cs

forceList :: forall a . (a -> ()) -> [a] -> ()
forceList _ [] = ()
forceList f (a:as) = case f a of { () -> forceList f as }

writeSerialized :: FilePath -> a -> IO ()
writeSerialized _ _ = error "writeSerialized"

eqBool :: Bool -> Bool -> Bool
eqBool True  x = x
eqBool False x = not x

neBool :: Bool -> Bool -> Bool
neBool True  x = not x
neBool False x = x

-- Temporary until overloading
primIsInt        :: Any -> Bool
primIsInt         = error "isInt"
primIsIO         :: Any -> Bool
primIsIO          = error "isIO"

newtype Exn = Exn String
  deriving (Show)
instance Exception Exn

isPrefixOfBy :: forall a . (a -> a -> Bool) -> [a] -> [a] -> Bool
isPrefixOfBy _ [] _ = True
isPrefixOfBy _ _ [] = False
isPrefixOfBy eq (c:cs) (d:ds) = eq c d && isPrefixOfBy eq cs ds

isEQ :: Ordering -> Bool
isEQ EQ = True
isEQ _  = False

compareString :: String -> String -> Ordering
compareString = compare
