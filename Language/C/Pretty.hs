{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE FlexibleInstances #-}

-- |
-- Module      :  Language.C.Pretty
-- Copyright   :  (c) Harvard University 2006-2011
--                (c) Geoffrey Mainland 2011-2012
-- License     :  BSD-style
-- Maintainer  :  mainland@eecs.harvard.edu

module Language.C.Pretty where

import Data.Char (isAlphaNum,
                  isLower)
import Data.Loc
import Language.C.Syntax
import Text.PrettyPrint.Mainland

pprLoc :: SrcLoc -> Doc -> Doc
pprLoc loc doc = srcloc loc <> doc

data Fixity = Fixity Assoc Int
  deriving (Eq, Ord)

data Assoc = LeftAssoc | RightAssoc | NonAssoc
  deriving (Eq, Ord)

infix_ :: Int -> Fixity
infix_ = Fixity NonAssoc

infixl_ :: Int -> Fixity
infixl_ = Fixity LeftAssoc

infixr_ :: Int -> Fixity
infixr_ = Fixity RightAssoc

infixop :: (Pretty a, Pretty b, Pretty op, CFixity op)
        => Int -- ^ precedence of context
        -> op  -- ^ operator
        -> a   -- ^ left argument
        -> b   -- ^ right argument
        -> Doc
infixop prec op l r =
    parensIf (prec > opPrec) $
    pprPrec leftPrec l <+> ppr op <+/> pprPrec rightPrec r
  where
    leftPrec | opAssoc == RightAssoc = opPrec + 1
             | otherwise             = opPrec

    rightPrec | opAssoc == LeftAssoc = opPrec + 1
              | otherwise            = opPrec

    Fixity opAssoc opPrec = fixity op

parensList :: [Doc] -> Doc
parensList = encloseSep lparen rparen comma

bracesList :: [Doc] -> Doc
bracesList = encloseSep lbrace rbrace comma

bracesSemiList :: [Doc] -> Doc
bracesSemiList = encloseSep lbrace rbrace semi

pprAnti :: String -> String -> Doc
pprAnti anti s = char '$' <> text anti <> colon <>
                 if isIdentifier s then text s else parens (text s)
  where
    isIdentifier :: String -> Bool
    isIdentifier []       = False
    isIdentifier ('_':cs) = all isIdChar cs
    isIdentifier (c:cs)   = isLower c && all isIdChar cs

    isIdChar :: Char -> Bool
    isIdChar '_' = True
    isIdChar c   = isAlphaNum c

class CFixity a where
    fixity :: a -> Fixity

-- Fixities are taken from Table 2-1 in Section 2.12 of K&R (2nd ed.)

instance CFixity BinOp where
    fixity Add  = infixl_ 12
    fixity Sub  = infixl_ 12
    fixity Mul  = infixl_ 13
    fixity Div  = infixl_ 13
    fixity Mod  = infixl_ 13
    fixity Eq   = infixl_ 9
    fixity Ne   = infixl_ 9
    fixity Lt   = infixl_ 10
    fixity Gt   = infixl_ 10
    fixity Le   = infixl_ 10
    fixity Ge   = infixl_ 10
    fixity Land = infixl_ 5
    fixity Lor  = infixl_ 4
    fixity And  = infixl_ 8
    fixity Or   = infixl_ 6
    fixity Xor  = infixl_ 7
    fixity Lsh  = infixl_ 11
    fixity Rsh  = infixl_ 11

instance CFixity AssignOp where
    fixity _ = infixr_ 2

instance CFixity UnOp where
    fixity _ = infixr_ 14

instance Pretty Id where
    ppr (Id ident _)  = text ident
    ppr (AntiId v _)  = pprAnti "id" v

instance Show Id where
    showsPrec p = shows . pprPrec p

instance Pretty Storage where
    ppr (Tauto _)      = text "auto"
    ppr (Tregister _)  = text "register"
    ppr (Tstatic _)    = text "static"
    ppr (Textern _)    = text "extern"
    ppr (TexternL l _) = text "extern" <+> ppr l
    ppr (Ttypedef _)   = text "typedef"

instance Show Storage where
    showsPrec p = shows . pprPrec p

instance Pretty TypeQual where
    ppr (Tconst _)        = text "const"
    ppr (Tvolatile _)     = text "volatile"
    ppr (Tinline _)       = text "inline"

    ppr (Trestrict _)     = text "__restrict"

    ppr (TCUDAdevice _)   = text "__device__"
    ppr (TCUDAglobal _)   = text "__global__"
    ppr (TCUDAhost _)     = text "__host__"
    ppr (TCUDAconstant _) = text "__constant__"
    ppr (TCUDAshared _)   = text "__shared__"
    ppr (TCUDAnoinline _) = text "__noinline__"

    ppr (TCLprivate _)    = text "__private"
    ppr (TCLlocal _)      = text "__local"
    ppr (TCLglobal _)     = text "__global"
    ppr (TCLconstant _)   = text "__constant"
    ppr (TCLreadonly _)   = text "read_only"
    ppr (TCLwriteonly _)  = text "write_only"
    ppr (TCLkernel _)     = text "__kernel"

instance Show TypeQual where
    showsPrec p = shows . pprPrec p

instance Pretty Sign where
    ppr (Tsigned _)    = text "signed"
    ppr (Tunsigned _)  = text "unsigned"

instance Show Sign where
    showsPrec p = shows . pprPrec p

pprSign :: Maybe Sign -> Doc
pprSign Nothing     = empty
pprSign (Just sign) = ppr sign <> space

instance Pretty TypeSpec where
    ppr (Tvoid _)            = text "void"
    ppr (Tchar sign _)       = pprSign sign <> text "char"
    ppr (Tshort sign _)      = pprSign sign <> text "short"
    ppr (Tint sign _)        = pprSign sign <> text "int"
    ppr (Tlong sign _)       = pprSign sign <> text "long"
    ppr (Tlong_long sign _)  = pprSign sign <> text "long long"
    ppr (Tfloat _)           = text "float"
    ppr (Tdouble _)          = text "double"
    ppr (Tlong_double _)     = text "long double"

    ppr (Tstruct maybe_ident maybe_fields attrs _) =
        pprStructOrUnion "struct" maybe_ident maybe_fields attrs

    ppr (Tunion maybe_ident maybe_fields attrs _) =
        pprStructOrUnion "union" maybe_ident maybe_fields attrs

    ppr (Tenum maybe_ident cenums attrs _) =
        pprEnum maybe_ident cenums attrs

    ppr (Tnamed ident _) =
        ppr ident

    ppr (TtypeofExp e _) =
        text "__typeof__" <> parens (pprPrec 14 e)

    ppr (TtypeofType tipe _) =
        text "__typeof__" <> parens (ppr tipe)

    ppr (Tva_list _) =
        text "__builtin_va_list"

instance Show TypeSpec where
    showsPrec p = shows . pprPrec p

pprStructOrUnion :: String
                 -> Maybe Id
                 -> Maybe [FieldGroup]
                 -> [Attr]
                 -> Doc
pprStructOrUnion ty maybe_ident maybe_fields attrs =
    text ty
    <> case maybe_ident of
         Nothing ->    empty
         Just ident -> space <> ppr ident
    <> case maybe_fields of
           Nothing ->     empty
           Just fields -> space <> lbrace
                          <> nest 4 (line <> stack (zipWith (<>) (map ppr fields) (repeat semi)))
                          </> rbrace
    <> case attrs of
         [] -> empty
         _ ->  softline <> ppr attrs

pprEnum :: Maybe Id
        -> [CEnum]
        -> [Attr]
        -> Doc
pprEnum maybe_ident cenums attrs =
    text "enum"
    <> case maybe_ident of
         Nothing ->    empty
         Just ident -> space <> ppr ident
    <> case cenums of
         [] -> empty
         _  -> space <> lbrace <>
               nest 4 (line <> stack (punctuate comma (map ppr cenums))) </>
               rbrace
    <> case attrs of
         [] -> empty
         _ ->  softline <> ppr attrs

instance Pretty DeclSpec where
    ppr (DeclSpec storage quals spec _) =
        case map ppr storage ++ map ppr quals of
          [] ->   ppr spec
          docs -> spread docs <+/> ppr spec

    ppr (AntiDeclSpec v _) =
        pprAnti "spec" v

    ppr (AntiTypeDeclSpec storage quals v _) =
        spread (map ppr storage ++ map ppr quals) <+/>
        pprAnti "ty" v

instance Show DeclSpec where
    showsPrec p = shows . pprPrec p

instance Pretty ArraySize where
    ppr (ArraySize True e _)  = text "static" <+> ppr e
    ppr (ArraySize False e _) = ppr e
    ppr (VariableArraySize _) = text "*"
    ppr (NoArraySize _)       = empty

instance Show ArraySize where
    showsPrec p = shows . pprPrec p

pprDeclarator :: Maybe Id -> Decl -> Doc
pprDeclarator maybe_ident declarator =
    case maybe_ident of
      Nothing ->    pprDecl declarator empty
      Just ident -> pprDecl declarator (space <> ppr ident)
    where
      pprPtr :: Decl -> Doc -> (Decl, Doc)
      pprPtr (Ptr [] decl _) post =
          pprPtr decl $
          text "*" <> post
      pprPtr (Ptr quals decl _) post =
          pprPtr decl $
          text "*" <> spread (map ppr quals) <+> post
      pprPtr decl post = (decl, post)

      pprDirDecl :: Decl -> Doc -> (Decl, Doc)
      pprDirDecl (Array [] size decl _) pre =
          pprDirDecl decl $
          pre <> brackets (align (ppr size))

      pprDirDecl (Array quals size decl _) pre =
          pprDirDecl decl $
          pre <> brackets (align (spread (map ppr quals) <> ppr size))

      pprDirDecl (Proto decl args _) pre =
          pprDirDecl decl $
          pre <> parens (ppr args)

      pprDirDecl (OldProto decl args _) pre =
          pprDirDecl decl $
          pre <> parensList (map ppr args)

      pprDirDecl decl pre = (decl, pre)

      pprDecl :: Decl -> Doc -> Doc
      pprDecl decl mid =
          case decl' of
            DeclRoot _  -> declDoc
            _           -> pprDecl decl' (parens declDoc)
        where
          (decl', declDoc) = uncurry pprPtr (pprDirDecl decl mid)

instance Pretty Type where
    ppr (Type spec decl _)  = ppr spec <> pprDeclarator Nothing decl
    ppr (AntiType v _)      = pprAnti "ty" v

instance Show Type where
    showsPrec p = shows . pprPrec p

instance Pretty Designator where
    ppr (IndexDesignator e _)       = brackets $ ppr e
    ppr (MemberDesignator ident _)  = dot <> ppr ident

instance Show Designator where
    showsPrec p = shows . pprPrec p

instance Pretty Designation where
    ppr (Designation ds _) = folddoc (<>) (map ppr ds)

instance Show Designation where
    showsPrec p = shows . pprPrec p

instance Pretty Initializer where
    ppr (ExpInitializer e _) = ppr e

    ppr (CompoundInitializer inits _) =
        bracesList (map pprInit inits)
      where
        pprInit :: (Maybe Designation, Initializer) -> Doc
        pprInit (Nothing, init) = ppr init
        pprInit (Just d, init)  = ppr d <+> text "=" <//> ppr init

instance Show Initializer where
    showsPrec p = shows . pprPrec p

instance Pretty Init where
    ppr (Init ident decl maybe_asmlabel maybe_e attrs _) =
        pprDeclarator (Just ident) decl
        <> case attrs of
             [] -> empty
             _ ->  softline <> ppr attrs
        <> case maybe_asmlabel of
             Nothing -> empty
             Just l ->  space <> text "asm" <+> parens (text l)
        <> case maybe_e of
             Nothing -> empty
             Just e ->  space <> text "=" <+/> ppr e

instance Show Init where
    showsPrec p = shows . pprPrec p

instance Pretty Typedef where
    ppr (Typedef ident decl attrs loc) =
        ppr (Init ident decl Nothing Nothing attrs loc)

instance Show Typedef where
    showsPrec p = shows . pprPrec p

instance Pretty InitGroup where
    ppr (InitGroup spec attrs inits _) =
        ppr spec
        <> case attrs of
             [] -> empty
             _ ->  softline <> ppr attrs
        <> case inits of
             [] -> empty
             _ ->  commasep (map ppr inits)

    ppr (TypedefGroup spec attrs typedefs _) =
        text "typedef" <+> ppr spec
        <> case attrs of
             [] -> empty
             _ ->  softline <> ppr attrs
        <> case typedefs of
             [] -> empty
             _ ->  commasep (map ppr typedefs)

    ppr (AntiDecls v _)  = pprAnti "decls" v
    ppr (AntiDecl v _)   = pprAnti "decl" v

instance Show InitGroup where
    showsPrec p = shows . pprPrec p

instance Pretty Field where
    ppr (Field maybe_ident maybe_decl maybe_e _) =
        case maybe_decl of
          Nothing ->   empty
          Just decl -> pprDeclarator maybe_ident decl
        <>  case maybe_e of
              Nothing -> empty
              Just e ->  space <> colon <+> ppr e

instance Show Field where
    showsPrec p = shows . pprPrec p

instance Pretty FieldGroup where
    ppr (FieldGroup spec fields _) =
        ppr spec <> commasep (map ppr fields)

    ppr (AntiSdecls v _)  = pprAnti "sdecls" v
    ppr (AntiSdecl v _)   = pprAnti "sdecl" v

instance Show FieldGroup where
    showsPrec p = shows . pprPrec p

instance Pretty CEnum where
    ppr (CEnum ident maybe_e _) =
        ppr ident
        <> case maybe_e of
             Nothing -> empty
             Just e ->  space <> text "=" <+/> ppr e

    ppr (AntiEnums v _)  = pprAnti "enums" v
    ppr (AntiEnum v _)   = pprAnti "enum" v

instance Show CEnum where
    showsPrec p = shows . pprPrec p

instance Pretty Attr where
    ppr (Attr ident [] _) = ppr ident
    ppr (Attr ident args _) =
        ppr ident <> parens (commasep (map ppr args))

    pprList []    = empty
    pprList attrs = text "__attribute__" <>
                    parens (parens (commasep (map ppr attrs)))

instance Show Attr where
    showsPrec p = shows . pprPrec p

instance Pretty Param where
    ppr (Param maybe_ident spec decl _) =
        ppr spec <> pprDeclarator maybe_ident decl

    ppr (AntiParams v _)  = pprAnti "params" v
    ppr (AntiParam v _)   = pprAnti "param" v

instance Show Param where
    showsPrec p = shows . pprPrec p

instance Pretty Params where
    ppr (Params args True _) =
        commasep (map ppr args ++ [text "..."])

    ppr (Params args False _) =
        commasep (map ppr args)

instance Show Params where
    showsPrec p = shows . pprPrec p

instance Pretty Func where
    ppr (Func spec ident decl args body loc) =
        ppr spec <> pprDeclarator (Just ident) (Proto decl args loc)
        </> ppr body

    ppr (OldFunc spec ident decl args maybe_initgroups body loc) =
        ppr spec <> pprDeclarator (Just ident) (OldProto decl args loc)
        </> case maybe_initgroups of
              Nothing -> empty
              Just initgroups ->
                  stack (zipWith (<>) (map ppr initgroups) (repeat semi))
        </> ppr body

instance Show Func where
    showsPrec p = shows . pprPrec p

instance Pretty Definition where
    ppr (FuncDef func loc)     = srcloc loc <> ppr func
    ppr (DecDef initgroup loc) = srcloc loc <> ppr initgroup <> semi
    ppr (EscDef s loc)         = srcloc loc <> text s

    ppr (AntiFunc v _)    = pprAnti "func" v
    ppr (AntiEsc v _)     = pprAnti "esc" v
    ppr (AntiEdecls v _)  = pprAnti "edecls" v
    ppr (AntiEdecl v _)   = pprAnti "edecl" v

    pprList ds = stack (map ppr ds) <> line

instance Show Definition where
    showsPrec p = shows . pprPrec p

instance Pretty Stm where
    ppr (Label ident stm sloc) =
        srcloc sloc <>
        indent (-2) (line <> ppr ident <> colon) </> ppr stm

    ppr (Case e stm sloc) =
        srcloc sloc <>
        line <>
        indent (-2) (line <> text "case" <+> ppr e <> colon) </> ppr stm

    ppr (Default stm sloc) =
        srcloc sloc <>
        indent (-2) (line <> text "default" <> colon) </> ppr stm

    ppr (Exp Nothing sloc) =
        srcloc sloc <> semi

    ppr (Exp (Just e) sloc) =
        srcloc sloc <> hang 4 (ppr e) <> semi

    ppr (Block items sloc) =
        srcloc sloc <> ppr items

    ppr (If test then' maybe_else sloc) =
        srcloc sloc <>
        text "if" <+> parens (ppr test)
        <> pprStm then'
        <> case maybe_else of
             Nothing     -> empty
             Just else'  -> space <> text "else" <> pprStm else'
      where
        pprStm :: Stm -> Doc
        pprStm stm@(Block _ _)   = space <> ppr stm
        pprStm stm@(If _ _ _ _)  = space <> ppr stm
        pprStm stm               = nest 4 (line <> ppr stm) <> line

    ppr (Switch e stm sloc) =
        srcloc sloc <>
        text "switch" <+> parens (ppr e ) <+/> ppr stm

    ppr (While e stm sloc) =
        srcloc sloc <>
        text "while" <+> parens (ppr e) <+/> ppr stm

    ppr (DoWhile stm e sloc) =
        srcloc sloc <>
        text "do" <+/> ppr stm <+/> text "while" <> parens(ppr e) <> semi

    ppr (For ini test post stm sloc) =
        srcloc sloc <>
        text "for"
        <+> (parens . semisep) [either ppr ppr ini, ppr test, ppr post]
        <> case stm of
             Block {} -> space <> ppr stm
             _ -> nest 4 $ line <> ppr stm

    ppr (Goto ident sloc) =
        srcloc sloc <>
        text "goto" <+> ppr ident <> semi

    ppr (Continue sloc) =
        srcloc sloc <> text "continue" <>semi

    ppr (Break sloc) =
        srcloc sloc <> text "break" <> semi

    ppr (Return Nothing sloc) =
        srcloc sloc <> text "return" <> semi

    ppr (Return (Just e) sloc) =
        srcloc sloc <> nest 4 (text "return" <+> ppr e) <> semi

    ppr (Pragma pragma sloc) =
        srcloc sloc <> text "#pragma" <+> text pragma

    ppr (Asm isVolatile _ template outputs inputs clobbered sloc) =
        srcloc sloc <>
        text "__asm__"
        <> case isVolatile of
             True ->  space <> text "__volatile__"
             False -> empty
        <> parens (pprAsm inputs clobbered)
        <> semi
      where
        pprAsm :: [(String, Exp)] -> [String] -> Doc
        pprAsm [] [] =
            spread (map text template)
            <> case outputs of
                 [] -> space <> colon
                 _ ->  colon <+/> commasep (map pprReg outputs)

        pprAsm inputs clobbered =
            spread (map text template)
            <> case outputs of
                 [] -> space <> colon
                 _ ->  colon <+/> commasep (map pprReg outputs)
            <> case inputs of
                 [] -> space <> colon
                 _ ->  colon <+/> commasep (map pprReg inputs)
            <> case clobbered of
                 [] -> space <> colon
                 _ ->  colon <+/> commasep (map text clobbered)

        pprReg :: (String, Exp) -> Doc
        pprReg (reg, e) = text reg <+> parens (ppr e)

    ppr (AntiPragma v _) = pprAnti "pragma" v
    ppr (AntiStm v _)    = pprAnti "stm" v
    ppr (AntiStms v _)   = pprAnti "stms" v

instance Show Stm where
    showsPrec p = shows . pprPrec p

instance Pretty BlockItem where
    ppr (BlockDecl decl) = ppr decl <> semi
    ppr (BlockStm stm)   = ppr stm

    ppr (AntiBlockItem v _)  = pprAnti "item" v
    ppr (AntiBlockItems v _) = pprAnti "items" v

    pprList = embrace . loop
      where
        loop :: [BlockItem] -> [Doc]
        loop [] =
            []
        loop [item] =
            [ppr item]
        loop (item1@(BlockDecl _) : item2@(BlockStm _) : items) =
            (ppr item1 <> line) : loop (item2 : items)
        loop (item1@(BlockStm _) : item2@(BlockDecl _) : items) =
            (ppr item1 <> line) : loop (item2 : items)
        loop (item : items) =
            ppr item : loop items

        embrace :: [Doc] -> Doc
        embrace [] = lbrace <+> rbrace
        embrace ds = lbrace <>
                     nest 4 (line <> stack ds) </>
                     rbrace

instance Show BlockItem where
    showsPrec p = shows . pprPrec p

instance Pretty Const where
    ppr (IntConst s _ _ _)          = text s
    ppr (LongIntConst s _ _ _)      = text s
    ppr (LongLongIntConst s _ _ _)  = text s
    ppr (FloatConst s _ _)          = text s
    ppr (DoubleConst s _ _)         = text s
    ppr (LongDoubleConst s _ _)     = text s
    ppr (CharConst s _ _)           = text s
    ppr (StringConst ss _ _)        = sep (map string ss)

    ppr (AntiString v _)      = pprAnti "string"  v
    ppr (AntiChar v _)        = pprAnti "char"    v
    ppr (AntiLongDouble v _)  = pprAnti "ldouble" v
    ppr (AntiDouble v _)      = pprAnti "double"  v
    ppr (AntiFloat v _)       = pprAnti "float"   v
    ppr (AntiULInt v _)       = pprAnti "ulint"   v
    ppr (AntiLInt v _)        = pprAnti "lint"    v
    ppr (AntiULLInt v _)      = pprAnti "ullint"  v
    ppr (AntiLLInt v _)       = pprAnti "llint"   v
    ppr (AntiUInt v _)        = pprAnti "uint"    v
    ppr (AntiInt v _)         = pprAnti "int"     v

instance Show Const where
    showsPrec p = shows . pprPrec p

instance Pretty Exp where
    pprPrec _ (Var ident loc) = pprLoc loc $ ppr ident
    pprPrec _ (Const k loc) = pprLoc loc $ ppr k

    pprPrec p (BinOp op e1 e2 loc) =
        pprLoc loc $
        infixop p op e1 e2

    pprPrec p (Assign e1 op e2 loc) =
        pprLoc loc $
        infixop p op e1 e2

    pprPrec p (PreInc e loc) =
        pprLoc loc $
        parensIf (p > 14) $
        text "++" <> pprPrec 14 e

    pprPrec p (PostInc e loc) =
        pprLoc loc $
        parensIf (p > 15) $
        pprPrec 15 e <> text "++"

    pprPrec p (PreDec e loc) =
        pprLoc loc $
        parensIf (p > 14) $
        text "--" <> pprPrec 14 e

    pprPrec p (PostDec e loc) =
        pprLoc loc $
        parensIf (p > 15) $
        pprPrec 15 e <> text "--"

    pprPrec p (UnOp op e loc) =
        pprLoc loc $
        parensIf (p > 14) $
        ppr op <> pprPrec 14 e

    pprPrec p (SizeofExp e loc) =
        pprLoc loc $
        parensIf (p > 14) $
        text "sizeof" <> parens (pprPrec 14 e)

    pprPrec p (SizeofType tipe loc) =
        pprLoc loc $
        parensIf (p > 14) $
        text "sizeof" <> parens (ppr tipe)

    pprPrec p (Cast tipe e loc) =
        pprLoc loc $
        parensIf (p > 14) $
        parens (ppr tipe) <+> pprPrec 14 e

    pprPrec p (Cond test then' else' loc) =
        pprLoc loc $
        parensIf (p > 3) $
        pprPrec 3 test <+> text "?" <+>
        pprPrec 3 then' <+> colon <+> pprPrec 3 else'

    pprPrec p (Member e ident loc) =
        pprLoc loc $
        parensIf (p > 15) $
        pprPrec 15 e <> dot <> ppr ident

    pprPrec p (PtrMember e ident loc) =
        pprLoc loc $
        parensIf (p > 15) $
        pprPrec 15 e <> text "->" <> ppr ident

    pprPrec p (Index e1 e2 loc) =
        pprLoc loc $
        parensIf (p > 15) $
        pprPrec 15 e1 <> brackets (ppr e2)

    pprPrec p (FnCall f args loc) =
        pprLoc loc $
        parensIf (p > 15) $
        pprPrec 15 f <> parensList (map ppr args)

    pprPrec p (CudaCall f conf args loc) =
        pprLoc loc $
        parensIf (p > 15) $
        pprPrec 15 f <>
        text "<<<" <> pprConfig conf <> text ">>>" <>
        parensList (map ppr args)
      where
        pprConfig :: ExeConfig -> Doc
        pprConfig conf = commasep $
            [ppr (exeGridDim conf), ppr (exeBlockDim conf)] ++
            (case exeSharedSize conf of
               Nothing -> []
               Just e -> [ppr e])
            ++
            (case exeStream conf of
               Nothing -> []
               Just e -> [ppr e])

    pprPrec p (Seq e1 e2 loc) =
        pprLoc loc $
        parensIf (p > 1) $
        pprPrec 1 e1 <> comma <+/> pprPrec 1 e2

    pprPrec p (CompoundLit ty inits loc) =
        pprLoc loc $
        parensIf (p > 15) $
        parens (ppr ty) <+>
        braces (commasep (map pprInit inits))
      where
        pprInit :: (Maybe Designation, Initializer) -> Doc
        pprInit (Nothing, init) = ppr init
        pprInit (Just d, init)  = ppr d <+> text "=" <+/> ppr init

    pprPrec _ (StmExpr blockItems loc) =
        pprLoc loc $ parens $
        ppr blockItems

    pprPrec _ (BuiltinVaArg e ty loc) =
        pprLoc loc $
        text "__builtin_va_arg(" <> ppr e <> comma <+> ppr ty <> rparen

    pprPrec _ (AntiArgs v _)  = pprAnti "args"  v

    pprPrec _ (AntiExp v _)   = pprAnti "var"  v

instance Show Exp where
    showsPrec p = shows . pprPrec p

instance Pretty BinOp where
    ppr Add  = text "+"
    ppr Sub  = text "-"
    ppr Mul  = text "*"
    ppr Div  = text "/"
    ppr Mod  = text "%"
    ppr Eq   = text "=="
    ppr Ne   = text "!="
    ppr Lt   = text "<"
    ppr Gt   = text ">"
    ppr Le   = text "<="
    ppr Ge   = text ">="
    ppr Land = text "&&"
    ppr Lor  = text "||"
    ppr And  = text "&"
    ppr Or   = text "|"
    ppr Xor  = text "^"
    ppr Lsh  = text "<<"
    ppr Rsh  = text ">>"

instance Show BinOp where
    showsPrec p = shows . pprPrec p

instance Pretty AssignOp where
    ppr JustAssign = text "="
    ppr AddAssign  = text "+="
    ppr SubAssign  = text "-="
    ppr MulAssign  = text "*="
    ppr DivAssign  = text "/="
    ppr ModAssign  = text "%="
    ppr LshAssign  = text "<<="
    ppr RshAssign  = text ">>="
    ppr AndAssign  = text "&="
    ppr XorAssign  = text "^="
    ppr OrAssign   = text "|="

instance Show AssignOp where
    showsPrec p = shows . pprPrec p

instance Pretty UnOp where
    ppr AddrOf   = text "&"
    ppr Deref    = text "*"
    ppr Positive = text "+"
    ppr Negate   = text "-"
    ppr Not      = text "~"
    ppr Lnot     = text "!"

instance Show UnOp where
    showsPrec p = shows . pprPrec p
