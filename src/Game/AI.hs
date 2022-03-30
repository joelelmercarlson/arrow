{-# LANGUAGE OverloadedStrings #-}
{-

Game.AI.hs

Author: "Joel E Carlson" <joel.elmer.carlson@gmail.com>

-}
module Game.AI (aiAction) where

import Data.List
import qualified Data.Map.Strict as Map
import Engine.Arrow.Data (World(..))
import qualified Engine.Arrow.Compass as EAC
import qualified Game.Combat as GC
import qualified Game.Entity as GE
import qualified Game.Inventory as GI
import Game.Kind.Entity (EntityKind(..))
import qualified Game.Player as GP

data AI
  = Attack
  | Get
  | Heal
  | Move
  deriving (Show, Eq)

-- | aiAction
-- AI actions based on goal, HP, position...
-- TODO more actions, like throw, use items...
aiAction :: [(Int, EntityKind)] -> World -> World
aiAction [] w = w
aiAction ((mx, mEntity):xs) w = if mx == 0 || not (block mEntity)
  then aiAction xs w
  else let
  (_, pPos) = GP.getPlayer (entityT w)
  -- monster properties
  mPos  = coord mEntity
  mProp = property mEntity
  mHp    = eHP mEntity
  mSpawn = read $ Map.findWithDefault (show mPos) "spawn" mProp :: (Int, Int)
  mItems = GE.getEntityBy mPos (entityT w)
  -- action
  action
    | EAC.adjacent pPos mPos = Attack
    | length mItems > 1 = Get
    | mHp <= 5 && EAC.adjacent mSpawn mPos = Heal
    | otherwise = Move
  world = case action of
    Attack -> GC.mkCombat mx 0 w
    Heal   -> monsterHeal mx mEntity w
    Get    -> monsterGet mx mEntity w
    Move   -> pathFinder mx mEntity w
  -- newWorld w/ action
  in aiAction xs world

-- | monsterGet
-- M picks items based on affinity...
monsterGet :: Int -> EntityKind -> World -> World
monsterGet mx mEntity w = let
  mPos  = coord mEntity
  items = GE.getEntityBy mPos (entityT w)
  -- Get Action
  newMonster = if not (null items)
    then GI.pickUp items mEntity
    else mEntity
  newEntity = if not (null items)
    then GI.emptyBy mPos items (entityT w)
    else entityT w
  in w { entityT = GE.updateEntity mx newMonster newEntity }

-- | monsterHeal
-- M heals slowly...
monsterHeal :: Int -> EntityKind -> World -> World
monsterHeal mx mEntity w = let
  -- Heal Action
  heal = eHP mEntity + 1
  hp = if heal > eMaxHP mEntity then eMaxHP mEntity else heal
  in w { entityT = GE.updateEntityHp mx hp (entityT w) }

-- | pathFinder
-- 0. Don't move the Player at 0
-- 1. Distance from goal
--   a. 5 or less is *critical*
-- 2. Decide by distance
--    a. 4 is Vision
--    b. 7 is Hear
-- 3. Check blockList
-- 4. Update move
pathFinder :: Int -> EntityKind -> World -> World
pathFinder mx mEntity w = if mx == 0 || not (block mEntity)
  then w
  else let
  coordF :: [(Int, Int)] -> [(Int, Int)]
  coordF = filter (`notElem` blockT)
  blockT = [ xy | (_, xy) <- GE.fromBlock (entityT w) ]
  (_, pPos) = GP.getPlayer (entityT w)
  -- M properties
  mPos   = coord mEntity
  mProp  = property mEntity
  mSpawn = read $ Map.findWithDefault (show pPos) "spawn" mProp :: (Int, Int)
  -- flee goal if *critical* eHP
  mGoal  = if eHP mEntity <= 5 then mSpawn else pPos
  -- M move based on goal
  distList = [ (d, xy) | xy <- moveT mEntity, let d = EAC.chessDist mGoal xy ]
  moveList = coordF $
    [ xy | (d, pos) <- sort distList,
      let xy = if EAC.adjacent mPos mGoal || d >= 7 then mPos else pos ]
  move = if null moveList then mPos else head moveList
  in w { entityT = GE.updateEntityPos mx move (entityT w) }
