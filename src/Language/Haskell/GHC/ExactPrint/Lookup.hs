module Language.Haskell.GHC.ExactPrint.Lookup (keywordToString) where

import GHC (AnnKeywordId(..))

keywordToString :: AnnKeywordId -> String
keywordToString kw =
  case kw of
      AnnAs    -> "as"
      AnnAt   -> "@"
      AnnBang  -> "!"
      AnnBackquote   -> "`"
      AnnBy   -> "by"
      AnnCase  -> "case"
      AnnClass    -> "class"
--      AnnClose   -> ""
      AnnCloseC  -> "}"
      AnnCloseP  -> ")"
      AnnCloseS  -> "]"
      AnnColon    -> ":"
      AnnComma   -> ","
      AnnCommaTuple  -> ","
      AnnDarrow  -> "=>"
      AnnData   -> "data"
      AnnDcolon  -> "::"
      AnnDefault    -> "default"
      AnnDeriving   -> "deriving"
      AnnDo   -> "do"
      AnnDot   -> "."
      AnnDotdot  -> ".."
      AnnElse   -> "else"
      AnnEqual    -> "="
      AnnExport   -> "export"
      AnnFamily   -> "family"
      AnnForall   -> "forall"
      AnnForeign    -> "foreign"
--      AnnFunId   -> ""
      AnnGroup    -> "group"
--      AnnHeader  -> ""
--      for CType
      AnnHiding   -> "hiding"
      AnnIf   -> "if"
      AnnImport   -> "import"
      AnnIn   -> "in"
--      AnnInfix   -> ""
      AnnInstance   -> "instance"
      AnnLam    -> "\\"
      AnnLarrow  -> "<-"
      AnnLet    -> "let"
      AnnMdo    -> "mdo"
      AnnMinus   -> "-"
      AnnModule   -> "module"
      AnnNewtype   -> "newtype"
      AnnOf   -> "of"
      AnnOpen  -> ""
      AnnOpenC   -> "{"
      AnnOpenP   -> "("
      AnnOpenS   -> "["
--      AnnPackageName    -> "?"
      AnnPattern    -> "pattern"
      AnnProc   -> "proc"
      AnnQualified   -> "qualified"
      AnnRarrow  -> "->"
      AnnRec    -> "rec"
      AnnRole   -> "role"
      AnnSafe   -> "safe"
      AnnSemi  -> ";"
      AnnStatic  -> "static"
      AnnThen   -> "then"
      AnnTilde   -> "~"
      AnnTildehsh  -> "~#"
      AnnType   -> "type"
      AnnUnit  -> "()"
      AnnUsing    -> "using"
      AnnVbar  -> "|"
      AnnWhere    -> "where"
      Annlarrowtail  -> "-<"
      Annrarrowtail  -> "->"
      AnnLarrowtail  -> "-<<"
      AnnRarrowtail  -> ">>-"
      AnnEofPos -> ""

