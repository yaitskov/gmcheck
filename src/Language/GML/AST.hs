{-|
Module      : AST
Description : GML AST

Everything representing the Game Maker Language source tree.
-}

module Language.GML.AST where

import Data.Text

-- * GML values

{-| Literal constant in a source. -}
data Literal = LNumeric Double | LString String
    deriving (Eq, Show)

{-| Identifier (name. -}
type Name = String

{-| Variables that hold a value and may be read or changed. -}
data Variable
    = VVar    Name              -- ^ Local, self or global variable
    | VField  Name Variable     -- ^ Field/instance variable (possibly chained)
    | VArray  Name Expr         -- ^ One-dimensional array, indexed by a number
    | VArray2 Name (Expr, Expr) -- ^ Two-dimensional array, indexed by two numbers
    deriving (Eq, Show)

-- * Operators

{-| Arithetical and logical operations, used in both modification assignment and binary operations. -}
data NumOp
    = Add | Sub | Mul | Div
    | Mod | IntDiv
    | And | Or | Xor
    deriving (Eq, Show)

{-| Comparison operators. -}
data CompOp
    = Eq | NotEq | Less | Greater | LessEq | GreaterEq
    deriving (Eq, Show)

{-| Bitwise operations. -}
data BitOp
    = Shr | Shl | BitAnd | BitOr | BitXor
    deriving (Eq, Show)

{-| Unary operators, in order of precedence. -}
data UnOp
    = UBitNeg | UNeg | UNot
    | UPreInc  | UPreDec
    | UPostInc | UPostDec
    deriving (Eq, Show)

{-| Any binary operator. -}
data BinOp
    = BNum  NumOp
    | BComp CompOp
    | BBit  BitOp
    deriving (Eq, Show)

-- * Expressions

type FunName = String

{-| Expression which can be evaluated to a value. -}
data Expr
    = EUnary UnOp Expr        -- ^ Unary expression
    | EBinary BinOp Expr Expr -- ^ Binary expression
    | ETernary Expr Expr Expr -- ^ Ternary conditional [cond ? t : f]
    | EFuncall Name [Expr]    -- ^ Function/script call with arguments
    | EVar Variable
    | ELit Literal
    deriving (Eq, Show)

class Binary a where
    toBin :: a -> BinOp

instance Binary NumOp where
    toBin = BNum

instance Binary CompOp where
    toBin = BComp

instance Binary BitOp where
    toBin = BBit

eBinary :: Binary a => a -> Expr -> Expr -> Expr
eBinary = EBinary . toBin

-- * Statements

{-| Assigning operations, possibly with arithmetical/boolean modification. -}
data AssignOp
    = AAssign | AModify NumOp
    deriving (Eq, Show)

{-| Statement (instruction). -}
data Stmt
    = SExpression Expr -- ^ Calling an expression (typically a function/script with side effects)
    -- Variable declaration and modification
    | SDeclare Name (Maybe Expr)  -- ^ Declaring a local variable
    | SAssign Variable AssignOp Expr -- ^ Assigning or modifying an existing variable
    -- Control flow structures
    | SWith Variable Block  -- ^ Switchig the execution context to an another instance
    | SIf Expr Block Block -- ^ Conditional. If the `else` branch is missing, the second block is simply empty
    | SRepeat Expr Block   -- ^ Repeating some instructions several times
    | SWhile Expr Block    -- ^ Loop with a pre-condition
    | SDoUntil Block Expr  -- ^ Loop with a post-condition
    | SFor Stmt Expr Expr Block -- ^ For loop. TODO: limit stmt to assign/declare only
    | SSwitch Expr [([Expr], Block)]
    -- Control flow redirection
    | SBreak    -- ^ Break from a loop or switch-case
    | SContinue -- ^ Continue to the next loop iteration
    | SExit        -- ^ Exit from a script/event without a result
    | SReturn Expr -- ^ Return the result from a script
    deriving (Eq, Show)

{-| Any GML source is a list of statements. -}
type Source = [Stmt]

{-| A code sub-block is a bracketed list of statements. -}
type Block = Source