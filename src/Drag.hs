module Drag where

import Control.Applicative
import Control.Monad
import Data.Maybe
import SDL.Geometry
import Directional
import GameState
import Utils.Utils

class Draggable d where
  setCoord :: Point Int -> d -> Maybe d
  applyMove :: GridDirection -> d -> d
  checkMove :: GridDirection -> d -> Bool

data MoveAmount a = FullMove | PartialMove a deriving Show
type DragMove a = (GridDirection, MoveAmount a, Point Int)
data DragResult a b = DragResult (Point (Point a)) b (Maybe (DragMove a)) deriving Show
data PartialMoveResult a = PartialMoveResult GridDirection a (Point Int) deriving Show
data FullMoveResult = FullMoveResult GridDirection (Point Int) deriving Show

toTileCoord :: RealFrac a => GridDrawInfo a -> Point a -> Point Int
toTileCoord (GridDrawInfo scale origin) click = pairMap floor (pairAp (pairMap (/) (click - origin)) scale)

clickTile :: (RealFrac a, Draggable t) =>  GridDrawInfo a -> Point a -> t -> Maybe t
clickTile drawInfo click = setCoord (toTileCoord drawInfo click)

dragDistance :: Num a => Point (Point a) -> Point a
dragDistance (x, x') = x' - x

dragDirection :: (Num a, Ord a, Draggable t) => Point (Point a) -> t -> Maybe (GridOriented a)
dragDirection d z = collapse (<) (toMaybe <$> trySlide <*> dist)
  where dist = degenerateRect (dragDistance d)
        canSlide = generateRect (`checkMove` z)
        trySlide = (&&) <$> ((>0) <$> ((*) <$> dist <*> signedRect)) <*> canSlide

-- a rectangle on the edge of the tile, but not outside
tileRect :: Num a => GridDrawInfo a -> Point Int -> Rectangular a
tileRect (GridDrawInfo scale origin) coord =
  (+) <$> fromBottomRight scale' <*> degenerateRect origin'
  where scale' = scale - (1, 1)
        coord' = pairMap fromIntegral coord
        origin' = (origin + (scale * coord'))

-- a rectangle just outside the tile
tileBoundingRect :: Num a => GridDrawInfo a -> Point Int -> Rectangular a
tileBoundingRect drawInfo coord = (+) <$> signedRect <*> tileRect drawInfo coord

toBoundingRect :: (Ord a, RealFrac a) => GridDrawInfo a -> Point Int -> Point a -> GridDirection -> Rectangular a
toBoundingRect drawInfo@(GridDrawInfo scale _) coord click dir = extend <*> rect' <*> scaledSignedRect scale
  where rect = tileBoundingRect drawInfo coord
        click' = (+) <$> signedRect <*> degenerateRect click
        rect' = clip <*> click' <*> rect
        clip = injectOriented_ (GridOriented dir const) (\_ x -> x)
        extend = injectOriented_ (GridOriented dir (+)) const

dragResultHasFullMove :: DragResult a b -> Bool
dragResultHasFullMove (DragResult _ _ move) = maybe False test move
  where test (_, m, _) = case m of FullMove -> True
                                   _ -> False

resultDrag :: DragResult a b -> Point (Point a)
resultDrag (DragResult drag _ _) = drag

resultTile :: DragResult a b -> b
resultTile (DragResult _ tile _) = tile

resultDir :: DragResult a b -> Maybe GridDirection
resultDir (DragResult _ _ move) = fmap (\(x, _, _) -> x) move

dragResult :: (Ord a, RealFrac a, Draggable b) => GridDrawInfo a -> Point (Point a) -> b -> DragResult a b
dragResult drawInfo drag@(click, end) z = case dirM of
  Just (GridOriented dir dragDist) -> case intersection of
    Nothing -> DragResult drag z $ Just (dir, PartialMove dragDist, coord)
    Just (GridOriented intersectDir click') ->
      if completedMove then DragResult drag' tile' $ Just (dir, FullMove, coord)
      else DragResult drag' tile' Nothing
      where drag' = (click', end)
            tile' = fromMaybe z tileM
            completedMove = intersectDir == dir || shouldConvert drawInfo (GridOriented dir dragDist)
    where intersection = drag `intersect` (toBoundingRect drawInfo coord click dir)
  Nothing -> case intersection of
    Nothing -> DragResult drag z Nothing
    Just (GridOriented intersectDir click') -> DragResult drag' tile' Nothing
      where drag' = (click', end)
            tile' = fromMaybe z tileM
    where intersection = drag `intersect` (tileBoundingRect drawInfo coord)
  where dirM = dragDirection drag =<< tileM
        coord = toTileCoord drawInfo click
        tileM = setCoord coord z

completelyApplyDrag :: (Ord a, RealFrac a, Draggable b) => GridDrawInfo a -> Point (Point a) -> b -> (Point (Point a), Maybe (PartialMoveResult a), b)
completelyApplyDrag drawInfo drag z =
  case move of
    Nothing -> (drag', Nothing, clickZ)
    Just (dir, amount, coord) -> case amount of
      FullMove -> completelyApplyDrag drawInfo drag' z'
        where z' = applyMove dir clickZ
      PartialMove x -> (drag', Just (PartialMoveResult dir x coord), clickZ)
  where (DragResult drag' clickZ move) = dragResult drawInfo drag z

shouldConvert :: (Ord a, RealFrac a) => GridDrawInfo a -> GridOriented a -> Bool
shouldConvert (GridDrawInfo scale _) (GridOriented dir dist) =
  (axisScale / 2) < abs dist
  where axisScale = extract dir (degenerateRect scale)

convertPartialMove :: (Ord a, RealFrac a) => GridDrawInfo a -> PartialMoveResult a -> Maybe FullMoveResult
convertPartialMove drawInfo (PartialMoveResult dir dist coord) =
  if shouldConvert drawInfo (GridOriented dir dist) then Just $ FullMoveResult dir coord else Nothing

applyFullMove :: Draggable t => FullMoveResult -> t -> t
applyFullMove (FullMoveResult dir coord) z = applyMove dir z'
  where z' = fromMaybe (error "full move should've been checked beforehand") $
             setCoord coord z

