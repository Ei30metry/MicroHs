module MicroHs.CompileCache(
  CModule,
  Cache, addWorking, getWorking, emptyCache, deleteFromCache, workToDone, addBoot, getBoots,
  cachedModules, cachedModuleNames, lookupCache, lookupCacheChksum, getImportDeps,
  addPackage, getCompMdls, getPathPkgs, getPkgs,
  getCacheTables, setCacheTables,
  saveCache, loadCached,
  ) where
import Prelude(); import MHSPrelude
import MicroHs.Desugar(LDef)
import Language.MicroHs.Expr(IdentModule)
import Language.MicroHs.Ident(showIdent)
import qualified MicroHs.IdentMap as M
import MicroHs.Package
import MicroHs.TypeCheck(TModule, tModuleName, GlobTables, emptyGlobTables, mergeGlobTables)
import System.IO
import System.IO.Serialize
import System.IO.MD5(MD5CheckSum)
import Compat

type CModule = (TModule [LDef], [IdentModule], MD5CheckSum)

data CacheEntry =
   CompMdl                              -- module compiled in in this session
    (TModule [LDef])                    -- the cached module
    [IdentModule]                       -- imported module names
    MD5CheckSum                         -- checksum of the source file
  | PkgMdl                              -- module from a package
    (TModule [LDef])                    -- the cached module
--  deriving (Show)

tModuleOf :: CacheEntry -> TModule [LDef]
tModuleOf (CompMdl t _ _) = t
tModuleOf (PkgMdl t) = t

chksumOf :: CacheEntry -> MD5CheckSum
chksumOf (CompMdl _ _ k) = k
chksumOf _ = undefined

data Cache = Cache {
  working :: [IdentModule],             -- modules currently being processed (used to detected circular imports)
  boots   :: [IdentModule],             -- modules where only the boot version has been compiled
  cache   :: M.Map CacheEntry,          -- cached compiled modules
  pkgs    :: [(FilePath, Package)],     -- loaded packages
  tables  :: GlobTables
  }
--  deriving (Show)

getCacheTables :: Cache -> GlobTables
getCacheTables = tables

setCacheTables :: GlobTables -> Cache -> Cache
setCacheTables ct c = c{ tables = ct }

emptyCache :: Cache
emptyCache =
  Cache { working = [], boots = [], cache = M.empty, pkgs = [], tables = emptyGlobTables }

deleteFromCache :: IdentModule -> Cache -> Cache
deleteFromCache mn c = c{ cache = M.delete mn (cache c) }

addBoot :: IdentModule -> Cache -> Cache
addBoot mn c = c{ boots = mn : boots c }

getBoots :: Cache -> [IdentModule]
getBoots = boots

getWorking :: Cache -> [IdentModule]
getWorking = working

addWorking :: IdentModule -> Cache -> Cache
addWorking mn c =
  let ws = working c
  in  if elem mn ws then
        error $ "recursive module: " ++ showIdent mn ++ ", import chain: " ++ unwords (map showIdent ws)
      else
        c{ working = mn : ws }

workToDone :: CModule -> Cache -> Cache
workToDone (t, i, k) c@(Cache{ working = mn:ws, boots = bs, cache = m }) =
  c{ working = ws, boots = filter (/= mn) bs, cache = M.insert mn (CompMdl t i k) m }
workToDone _ _ = undefined

cachedModules :: Cache -> [TModule [LDef]]
cachedModules = map tModuleOf . M.elems . cache

cachedModuleNames :: Cache -> [IdentModule]
cachedModuleNames = M.keys . cache

lookupCache :: IdentModule -> Cache -> Maybe (TModule [LDef])
lookupCache mn c = tModuleOf <$> M.lookup mn (cache c)

lookupCacheChksum :: IdentModule -> Cache -> Maybe MD5CheckSum
lookupCacheChksum mn c = chksumOf <$> M.lookup mn (cache c)

getImportDeps :: Cache -> [(IdentModule, [IdentModule])]
getImportDeps cash = [ (tModuleName tm, imps) | CompMdl tm imps _ <- M.elems (cache cash) ]

getCompMdls :: Cache -> [TModule [LDef]]
getCompMdls cash = [ tm | CompMdl tm _ _ <- M.elems (cache cash) ]

getPathPkgs :: Cache -> [(FilePath, Package)]
getPathPkgs = pkgs

getPkgs :: Cache -> [Package]
getPkgs = map snd . pkgs

addPackage :: FilePath -> Package -> Cache -> Cache
addPackage f p c = c{
  pkgs = (f, p) : pkgs c,
  cache = foldr ins (cache c) (pkgExported p ++ pkgOther p),
  tables = mergeGlobTables (pkgTables p) (tables c)
  }
  where ins t = M.insert (tModuleName t) (PkgMdl t)

saveCache :: FilePath -> Cache -> IO ()
saveCache fn cash = writeSerializedCompressed fn cash

loadCached :: FilePath -> IO (Maybe Cache)
loadCached fn = do
  mhin <- openFileM fn ReadMode
  case mhin of
    Nothing ->
      return Nothing
    Just hin -> do
      hClose hin
      Just <$> readSerialized fn
