{-# LANGUAGE OverloadedStrings #-}

module Language.GML.Parser.AST
    ( Source, Result
    , parseSource
    ) where

import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L
import Control.Monad.Combinators.Expr
import Data.Text hiding (empty, map)

import Language.GML.AST
import Language.GML.Parser.Common

-- * Basic tokens

keyword :: Text -> Parser Text
keyword kw = lexeme (string kw <* notFollowedBy alphaNumChar)

varName = ident <?> "variable"
funName = ident <?> "function or script"

-- * Values

-- |Number literal.
lNumeric :: Parser Literal
lNumeric = LNumeric <$>
    (try (lexeme (L.signed empty L.float))
    <|> fromIntegral <$> lexeme (L.signed empty L.decimal))

-- |String literal.
lString :: Parser Literal
lString = LString <$> (char '\"' *> manyTill L.charLiteral (char '\"'))

literal = lNumeric <|> lString

variable = do
    name <- varName
    choice
        [ VField name <$> (symbol "." *> variable)
        , try $ VArray name <$> brackets expr
        , VArray2 name <$> brackets ((,) <$> expr <*> (symbol "," *> expr))
        , pure $ VVar name
        ]

-- * Expressions

funcall = EFuncall <$> funName <*> parens (sepBy expr $ symbol ",")

opTable :: [[Operator Parser Expr]]
opTable =
    [   [ prefix "-" (EUnary UNeg)
        , prefix "~" (EUnary UBitNeg)
        , prefix "!" (EUnary UNot)
        , prefix "+" id
        ]
    ,   [ binary "div" (eBinary IntDiv)
        , binary "%"   (eBinary Mod)
        , binary "mod" (eBinary Mod)
        ]
    ,   [ prefix  "--" (EUnary UPreDec)
        , prefix  "++" (EUnary UPreInc)
        , postfix "--" (EUnary UPostDec)
        , postfix "++" (EUnary UPostInc)
        ]
    ,   [ binary "|"  (eBinary BitOr)
        , binary "&"  (eBinary BitAnd)
        , binary "^"  (eBinary BitXor)
        , binary ">>" (eBinary Shr)
        , binary "<<" (eBinary Shl)
        ]
    ,   [ binary "*"  (eBinary Mul)
        , binary "/"  (eBinary Div)
        ]
    ,   [ binary "+"  (eBinary Add)
        , binary "-"  (eBinary Sub)
        ]
    ,   [ binary "<"  (eBinary Less)
        , binary "==" (eBinary Eq)
        , binary "!=" (eBinary NotEq)
        , binary ">"  (eBinary Greater)
        , binary "<=" (eBinary LessEq)
        , binary ">=" (eBinary GreaterEq)
        ]
    ,   [ binary "&&" (eBinary And)
        , binary "||" (eBinary Or)
        , binary "^^" (eBinary Xor)
        ]
    ]

binary :: Text -> (Expr -> Expr -> Expr) -> Operator Parser Expr
binary  name f = InfixL  (f <$ symbol name)

prefix, postfix :: Text -> (Expr -> Expr) -> Operator Parser Expr
prefix  name f = Prefix  (f <$ symbol name)
postfix name f = Postfix (f <$ symbol name)

eTerm = choice [parens expr, ELit <$> literal, try funcall, EVar <$> variable]

expr :: Parser Expr
expr = makeExprParser eTerm opTable <?> "expression"

assignOp = choice (map (\(c, s) -> c <$ symbol s) ops) <?> "assignment" where
    ops =
        [ (AAssign, "="), (AAssign, ":=")
        , (AModify Add, "+="), (AModify Sub, "-=")
        , (AModify Mul, "*="), (AModify Div, "/=")
        , (AModify Or,  "|="), (AModify And, "&="), (AModify Xor, "^=")
        ]

-- * Statements

-- | A single statement, optionally ended with a semicolon.
stmt :: Parser Stmt
stmt = (choice
    [ SDeclare <$> (keyword "var" *> varName) <*> optional (assignOp *> expr)
    , SWith    <$> (keyword "with" *> variable) <*> block
    , SIf      <$> (keyword "if" *> expr) <*> block <*> option [] (keyword "else" *> block)
    , SRepeat  <$> (keyword "repeat" *> expr) <*> block
    , SWhile   <$> (keyword "while" *> expr) <*> block
    , SDoUntil <$> (keyword "do" *> block) <*> (keyword "until" *> expr)
    , SBreak  <$ keyword "break", SContinue <$ keyword "continue", SExit <$ keyword "exit"
    , SReturn <$> (keyword "return" *> expr)
    , SAssign <$> variable <*> assignOp <*> expr
    ] <?> "statement")
    <* optional semicolon

-- | A block of multiple statements.
block = ((symbol "{" <|> keyword "begin") *> manyTill stmt (symbol "}" <|> keyword "end"))
    <|> (:[]) <$> stmt

parseSource :: String -> Text -> Result Source
parseSource = parseMany stmt