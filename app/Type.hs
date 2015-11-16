module Type where

import Prelude hiding (and, or)

import Unit
import Control.Monad

data Type = Numeric (Maybe Unit)
          | Fun Type [(Maybe String, Type)] Bool -- returnType argNamesAndTypes acceptsVarArgs
          | Struct String
          | Void
          | Other
    deriving (Show, Eq)

one :: Type
one = Numeric (Just Unit.one)

add :: Type -> Type -> Maybe Type
add (Numeric (Just t1)) (Numeric (Just t2)) | t1 == t2 = Just (Numeric (Just t1))
add (Numeric Nothing) (Numeric Nothing) = Just (Numeric Nothing)
add _ _ = Nothing

sub :: Type -> Type -> Maybe Type
sub (Numeric (Just t1)) (Numeric (Just t2)) | t1 == t2 = Just (Numeric (Just t1))
sub (Numeric Nothing) (Numeric Nothing) = Just (Numeric Nothing)
sub _ _ = Nothing

mul :: Type -> Type -> Maybe Type
mul (Numeric (Just t1)) (Numeric (Just t2)) = Just (Numeric (Just (Unit.mul t1 t2)))
mul (Numeric Nothing) (Numeric Nothing) = Just (Numeric Nothing)
mul _ _ = Nothing

div :: Type -> Type -> Maybe Type
div (Numeric (Just t1)) (Numeric (Just t2)) = Just (Numeric (Just (Unit.div t1 t2)))
div (Numeric Nothing) (Numeric Nothing) = Just (Numeric Nothing)
div _ _ = Nothing

rem :: Type -> Type -> Maybe Type
rem = sub

shl :: Type -> Type -> Maybe Type
shl t1 t2 =
  if numeric t1 then
    case t2 of
      Numeric (Just u) ->
       if u == Unit.one then
         Just t1
       else
         Nothing
      _ -> Nothing
  else
    Nothing

shr :: Type -> Type -> Maybe Type
shr = shl

and :: Type -> Type -> Maybe Type
and = add

or :: Type -> Type -> Maybe Type
or = and

land :: Type -> Type -> Maybe Type
land = and

lor :: Type -> Type -> Maybe Type
lor = or

xor :: Type -> Type -> Maybe Type
xor = or

assignable :: Type -> Type -> Bool
assignable to from =
    -- TODO do this better
    case merge to from of
      Nothing -> False
      Just _ -> True

numeric :: Type -> Bool
numeric t =
  case t of
    Numeric _ -> True
    _ -> False

merge :: Type -> Type -> Maybe Type
merge t1 t2 =
    case (t1, t2) of
      (Numeric m1, Numeric m2) ->
          case (m1, m2) of
            (Just u1, Just u2) -> if u1 == u2 then Just (Numeric (Just u1)) else Nothing
            (Just u1, Nothing) -> Just (Numeric (Just u1))
            (Nothing, Just u2) -> Just (Numeric (Just u2))
            (Nothing, Nothing) -> Just (Numeric Nothing)
      (Fun r1 a1 d1, Fun r2 a2 d2) ->
          -- maybe monad
          do r <- merge r1 r2
             a <- mapM (uncurry mergeArg) (zip a1 a2)
             guard (d1 == d2)
             return (Fun r a d1)
      (Struct n1, Struct n2) -> if n1 == n2 then Just t1 else Nothing
      (Other, Other) -> Just Other
      (Void, _) -> Just t2 -- TODO maybe merging Void with anything is a bad idea?
      (_, Void) -> Just t1
      _ -> Nothing

mergeArg :: (Maybe String, Type) -> (Maybe String, Type) -> Maybe (Maybe String, Type)
mergeArg (name1, ty1) (name2, ty2) =
  do ty <- merge ty1 ty2
     return (name1 `mplus` name2, ty)

mergeMaybe :: Maybe Type -> Maybe Type -> Maybe Type
mergeMaybe m1 m2 =
    case (m1, m2) of
      (Just t1, Just t2) -> merge t1 t2
      (Just t1, Nothing) -> Just t1
      (Nothing, Just t2) -> Just t2
      (Nothing, Nothing) -> Nothing

monomorphize :: Type -> Type
monomorphize t =
    case t of
      Numeric Nothing -> Numeric (Just Unit.one) -- polymorphic unit becomes unit 1
      _ -> t
