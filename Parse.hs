module Parse(
  pTop,
  parseDie,
  Ident,
  Def(..),
  Expr(..),
  Module(..),
  ) where
import Control.Monad
import Control.Monad.State.Strict
import ParserComb
import Control.Applicative --hiding (many, some)
--import Debug.Trace

type P a = Prsr [Int] a

type Ident = String

data Def = Data LHS [Constr] | Fcn LHS Expr
  deriving (Show)

data Expr = EVar Ident | EApp Expr Expr | ELam Ident Expr | EInt Integer | ECase Expr [(LHS, Expr)]
  deriving (Show)

data Module = Module Ident [Def]
  deriving (Show)

type LHS = (Ident, [Ident])
type Constr = (Ident, [Type])
type Type = Expr

skipWhite :: P a -> P a
skipWhite p = p <* pWhite

skipWhite' :: P a -> P a
skipWhite' p = p <* emany (char ' ')

-- Skip white-space.
-- If there is a newline, return the indentation of the last line.
pIndent :: P (Maybe String)
pIndent = do
  s <- emany (satisfy "white-space" (`elem` " \n\r"))
  let s' = takeWhile (== ' ') $ reverse s
  if s == s' then
    pure Nothing
   else
    pure $ Just s'

pWhite :: P ()
pWhite = do
  xx <- restOfInput
  msp <- pIndent
--  traceM $ "pWhite " ++ show (xx, msp)
  case msp of
    Nothing -> pure ()
    Just sp -> do
      st <- get
      case st of
        [] -> pure ()
        i : is -> do
          let
            c = length sp
          if c < i then do
--            traceM ("inject " ++ show ('}':sp))
            inject ('}' : '\n' : sp)
            put is
           else if c > i then
            pure ()
           else do
            eof <|> do --traceM "inject ;"
                       inject ";"

esepBy1 :: Prsr s a -> Prsr s sep -> Prsr s [a]
esepBy1 p sep = do
  x <- p
  xs <- emany (sep *> p)
  return (x:xs)

esepBy :: Prsr s a -> Prsr s sep -> Prsr s [a]
esepBy p sep = esepBy1 p sep <|> pure []

parseDie :: (Show a) => P a -> FilePath -> String -> a
parseDie p fn file =
  case runPrsr [] p fn file of
    Left err -> error err
    Right [(x, _)] -> x
    Right as -> error $ "Ambiguous:\n" ++ unlines (map (show . fst) as)

-------

pTop :: P Module
pTop = skipWhite (pure ()) *> pModule <* eof

pModule :: P Module
pModule = Module <$> (pKeyword "module" *> pUIdent <* pKeyword' "where") <*> pBlock pDef

pKeyword :: String -> P ()
pKeyword kw = (skipWhite $ do
  s <- pIdentRest
  guard (kw == s)
  pure ()
  ) <?> kw

pKeyword' :: String -> P ()
pKeyword' kw = (skipWhite' $ do
  s <- pIdentRest
  guard (kw == s)
  pure ()
  ) <?> kw

pLIdent :: P String
pLIdent = skipWhite $ do
  s <- (:) <$> (satisfy "lower case" (\ c -> 'a' <= c && c <= 'z')) <*> pIdentRest
  guard $ s `notElem` keywords
  pure s

keywords :: [String]
keywords = ["case", "data", "module", "of", "where"]

pUIdent :: P String
pUIdent = skipWhite $
  (:) <$> (satisfy "upper case" (\ c -> 'A' <= c && c <= 'Z')) <*> pIdentRest

pIdentRest :: P String
pIdentRest = emany $ satisfy "letter, digit" $ \ c ->
  'a' <= c && c < 'z' ||
  'A' <= c && c < 'Z' ||
  '0' <= c && c < '9' ||
  c == '_' || c == '\''

pInt :: P Integer
pInt = (read <$> (skipWhite $ esome $ satisfy "digit" (\ c -> '0' <= c && c <= '9'))) <?> "int"

pSymbol :: String -> P ()
pSymbol s = (skipWhite $ do
  s' <- esome $ satisfy "symbol" (`elem` "\\=+-:<>.!#$%^&*|~")
  guard (s == s')
  pure ()
  ) <?> s

pSym :: Char -> P ()
pSym c = () <$ (skipWhite $ char c)

pLHS :: P Ident -> P LHS
pLHS pId = (,) <$> pId <*> many pLIdent

pDef :: P Def
pDef =
      Data <$> (pKeyword "data" *> pLHS pUIdent <* pSymbol "=") <*> esepBy1 ((,) <$> pUIdent <*> many pAType) (pSymbol "|")
  <|> Fcn <$> (pLHS pLIdent <* pSymbol "=") <*> pExpr

pAType :: P Type
pAType = pAExpr

pAExpr :: P Expr
pAExpr =
  (EVar <$> pLIdent) <|> (EVar <$> pUIdent) <|> (EInt <$> pInt) <|> (pSym '(' *> pExpr <* pSym ')')

pExprApp :: P Expr
pExprApp = do
  f <- pAExpr
  as <- emany pAExpr
  pure $ foldl EApp f as

pLam :: P Expr
pLam = ELam <$> (pSymbol "\\" *> pLIdent) <*> (pSymbol "." *> pExpr)

pCase :: P Expr
pCase = ECase <$> (pKeyword "case" *> pExpr) <*> (pKeyword' "of" *> pBlock pArm)
  where pArm = (,) <$> (pLHS pUIdent <* pSymbol "->") <*> pExpr

pExpr :: P Expr
pExpr =
  pExprApp <|> pLam <|> pCase

pLCurl :: P ()
pLCurl = pSym '{' <|< softLC
  where softLC = do
          msp <- pIndent
          case msp of
            Nothing -> fail "\\n"
            Just sp -> do
--              traceM ("push " ++ show (length sp))
              modify $ \ st -> length sp : st

pRCurl :: P ()
pRCurl = pSym '}' <|> softRC
  where softRC = do
          is <- get
          if null is then
            fail "}"
           else do
            put (tail is)
            eof

pSemi :: P ()
pSemi = pSym ';'

pBlock :: P a -> P [a]
pBlock p = do
  pLCurl
  as <- esepBy p pSemi
  pRCurl
  pure as