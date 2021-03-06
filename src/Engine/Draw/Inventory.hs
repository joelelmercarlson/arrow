{-# LANGUAGE OverloadedStrings #-}
{-

Engine.Draw.Inventory.hs

This module draws the Menus...

Author: "Joel E Carlson" <joel.elmer.carlson@gmail.com>

-}
module Engine.Draw.Inventory (drawEquipment
                             , drawExamine
                             , drawInventory
                             , drawStore
                             , drawTarget) where

import Control.Monad (forM_)
import Control.Monad.IO.Class (MonadIO)
import SDL (($=))
import qualified SDL
import qualified SDL.Font
import Engine.Arrow.Data (World(..))
import qualified Engine.Draw.Textual as EDT
import qualified Engine.SDL.Util as U
import qualified Game.Player as GP

-- | drawEquipment
-- Show the Equipment
drawEquipment :: (MonadIO m) => SDL.Renderer -> World -> m ()
drawEquipment r w = do
  let logs = zip [0..] $ GP.characterEquipment (entityT w) (assetT w)
  renderDialog r (120, 10)
  fn <- SDL.Font.load "./assets/fonts/Hack-Regular.ttf" 14
  -- Journal
  forM_ logs $ \(i, j) -> do
    -- Text
    tx <- SDL.Font.blended fn green j
    sz <- SDL.Font.size fn j
    rt <- SDL.createTextureFromSurface r tx
    -- HUD
    let hudT = fromIntegral $ snd sz + (i * snd sz) :: Double
    EDT.renderText r rt sz (125, hudT)
    -- Cleanup
    SDL.freeSurface tx
    SDL.destroyTexture rt
  SDL.Font.free fn

-- | drawExamine
-- Show the Examine
drawExamine :: (MonadIO m) => SDL.Renderer -> World -> m ()
drawExamine r w = do
  let logs = zip [0..] $ GP.characterExamine (fovT w) (entityT w) (assetT w)
  fn <- SDL.Font.load "./assets/fonts/Hack-Regular.ttf" 14
  -- Journal
  forM_ logs $ \(i, j) -> do
    -- Text
    tx <- SDL.Font.blended fn white j
    sz <- SDL.Font.size fn j
    rt <- SDL.createTextureFromSurface r tx
    -- HUD
    let hudT = fromIntegral $ snd sz + (i * snd sz) :: Double
    EDT.renderText r rt sz (125, hudT)
    -- Cleanup
    SDL.freeSurface tx
    SDL.destroyTexture rt
  SDL.Font.free fn

-- | drawInventory
-- Show the Inventory
drawInventory :: (MonadIO m) => SDL.Renderer -> World -> m ()
drawInventory r w = do
  let logs = zip [0..] $ GP.characterInventory (entityT w) (assetT w)
  renderDialog r (120, 10)
  fn <- SDL.Font.load "./assets/fonts/Hack-Regular.ttf" 14
  -- Journal
  forM_ logs $ \(i, j) -> do
    -- Text
    tx <- SDL.Font.blended fn white j
    sz <- SDL.Font.size fn j
    rt <- SDL.createTextureFromSurface r tx
    -- HUD
    let hudT = fromIntegral $ snd sz + (i * snd sz) :: Double
    EDT.renderText r rt sz (125, hudT)
    -- Cleanup
    SDL.freeSurface tx
    SDL.destroyTexture rt
  SDL.Font.free fn

-- | drawStore
-- Show the Store
drawStore :: (MonadIO m) => SDL.Renderer -> World -> m ()
drawStore r w = do
  let logs = zip [0..] $ GP.characterStore (entityT w) (assetT w)
  renderDialog r (120, 10)
  fn <- SDL.Font.load "./assets/fonts/Hack-Regular.ttf" 14
  -- Journal
  forM_ logs $ \(i, j) -> do
    -- Text
    tx <- SDL.Font.blended fn yellow j
    sz <- SDL.Font.size fn j
    rt <- SDL.createTextureFromSurface r tx
    -- HUD
    let hudT = fromIntegral $ snd sz + (i * snd sz) :: Double
    EDT.renderText r rt sz (125, hudT)
    -- Cleanup
    SDL.freeSurface tx
    SDL.destroyTexture rt
  SDL.Font.free fn

-- | drawTarget
-- Show the Store
drawTarget :: (MonadIO m) => SDL.Renderer -> World -> m ()
drawTarget r _ = do
  let logs = zip [0..] GP.characterTarget
  fn <- SDL.Font.load "./assets/fonts/Hack-Regular.ttf" 14
  -- Journal
  forM_ logs $ \(i, j) -> do
    -- Text
    tx <- SDL.Font.blended fn yellow j
    sz <- SDL.Font.size fn j
    rt <- SDL.createTextureFromSurface r tx
    -- HUD
    let hudT = fromIntegral $ snd sz + (i * snd sz) :: Double
    EDT.renderText r rt sz (125, hudT)
    -- Cleanup
    SDL.freeSurface tx
    SDL.destroyTexture rt
  SDL.Font.free fn

-- | renderDialog
-- Background for Inventory functions
renderDialog :: (MonadIO m)
  => SDL.Renderer
  -> (Double, Double)
  -> m ()
renderDialog r (x, y) = do
  let bgRect = U.mkRect (floor x) (floor y) 520 375
  SDL.rendererDrawColor r $= SDL.V4 128 128 128 255
  SDL.fillRect r (Just bgRect)

-- | colors
green :: SDL.Font.Color
green = SDL.V4 0 255 0 255

white :: SDL.Font.Color
white = SDL.V4 255 255 255 255

yellow :: SDL.Font.Color
yellow = SDL.V4 255 255 0 255
