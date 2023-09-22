module CompatIO where
import Prelude hiding (Monad(..))
import qualified Prelude as P
import qualified Control.Monad as M

(>>=) :: IO a -> (a -> IO b) -> IO b
(>>=) = (P.>>=)

(>>) :: IO a -> IO b -> IO b
(>>) = (P.>>)

return :: a -> IO a
return = P.return

when :: Bool -> IO () -> IO ()
when = M.when

fail        :: forall a . String -> IO a
fail s       = error s

fmap :: (a -> b) -> IO a -> IO b
fmap = P.fmap
