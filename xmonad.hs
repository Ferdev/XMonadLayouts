{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE StandaloneDeriving    #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE LambdaCase #-}
{-# OPTIONS -Wno-incomplete-patterns #-}

import qualified Data.Map                         as M
import           XMonad
import           XMonad.Actions.Navigation2D
import           XMonad.Config.Desktop
import qualified XMonad.StackSet                  as W
import           MiddleColumn
import qualified Data.Map.Strict                  as Map
import           System.Process
import           XMonad.Actions.CopyWindow
import           XMonad.Actions.DynamicWorkspaces
import           XMonad.Actions.GridSelect
import           XMonad.Hooks.EwmhDesktops
import           XMonad.Layout.Spacing
import XMonad.Hooks.ManageDocks
import XMonad.Layout.MultiToggle
import XMonad.Layout.MultiToggle.Instances
import XMonad.Actions.CycleWS
import XMonad.Actions.Submap
import XMonad.Layout.SimpleDecoration
import XMonad.Hooks.InsertPosition
import XMonad.Actions.GroupNavigation
import Data.Monoid
import Control.Monad
import Data.List (elemIndex)
import XMonad.Layout.NoBorders
import XMonad.Layout.LayoutModifier


import WindowColumn
import WindowColumn as Column (Column(..))
import WindowFinder
--import MyUtils
--import FileLogger
import FocusWindow
import XMonad.Layout.MasterOverlay


data TitleBars = TitleBars deriving (Read, Show, Eq, Typeable)
instance Transformer TitleBars Window where
    transform _ x k = k (Mirror x) (\(Mirror x') -> x')

defaultThreeColumn :: (Float, Float, Float)
defaultThreeColumn = (0.15, 0.65, 0.2)

mySDConfig :: Theme
mySDConfig = def { fontName = "xft:Droid Sans Mono for Powerline.otf: Droid Sans Mono for Powerline:style=Regular:size=14",
  decoWidth = 3000
  ,decoHeight = 30
  , activeColor = "black"
  , inactiveColor = "black"
}

myManageHook :: Query (Data.Monoid.Endo WindowSet)
myManageHook = composeAll
    [ className =? "Gxmessage"      --> doFloat <+> doIgnore
    , className =? "Emacs"          --> doF W.swapMaster 
    , className =? "Thunderbird"    --> doShift ( myWorkspaces !! 4)
    , className =? "Enpass-Desktop" --> doShift ( myWorkspaces !! 0)
    ]

myWorkspaces :: [String]
myWorkspaces = [
         "1 (Core)"
        ,"2 (Work)"
        ,"3 (Work 2)"
        ,"4 (Net)"
        ,"5 (Email)"
        ,"6 (Distr)"
        ,"7 (Distr 2)"
        ,"8 (Net 2)"
    ]

main :: IO ()
main = xmonad $ ewmh $ navigation2D def
  (xK_k, xK_h, xK_j, xK_l)
  [
    (mod4Mask,               windowGo  ),
    (mod4Mask .|. shiftMask, windowSwap)
  ]
  True
  $ desktopConfig
    { borderWidth        = 3
    , terminal           = "gnome-terminal"
    , normalBorderColor  = "#cccccc"
    , focusedBorderColor = "#00FF00"
    , modMask     = mod4Mask
    , keys = myKeys <+> keys def
    , workspaces = myWorkspaces
    , layoutHook = -- simpleDeco shrinkText (mySDConfig) $
      desktopLayoutModifiers . smartBorders $
      mkToggle ((NOBORDERS ?? FULL ?? EOT)) (
        spacing 6 (ModifiedLayout (MasterOverlay Nothing) $ getMiddleColumnSaneDefault 2 0.2 defaultThreeColumn) |||
        spacing 6 (ModifiedLayout (MasterOverlay Nothing) $ getMiddleColumnSaneDefault 2 0.5 defaultThreeColumn) |||
        spacing 6 (ModifiedLayout (MasterOverlay Nothing) $ getMiddleColumnSaneDefault 3 0.75 (0.27333, 0.45333, 0.27333)) |||
        spacing 6 (ModifiedLayout (MasterOverlay Nothing) $ getMiddleColumnSaneDefault 3 0.75 (0.33333, 0.33333, 0.33333))
      )
    , handleEventHook = handleEventHook def <+> fullscreenEventHook
    , manageHook =  myManageHook <+> insertPosition End Newer <+> manageHook desktopConfig
    , logHook = historyHook
    }

myKeys :: XConfig l -> M.Map (KeyMask, KeySym) (X ())
myKeys conf@XConfig {XMonad.modMask = modm} =
  M.fromList $
    zip (zip (repeat (modm)) [xK_1..xK_9]) (map (withNthWorkspace W.greedyView) [0..])
  ++
    zip (zip (repeat (modm .|. shiftMask)) [xK_1..xK_9]) (map (withNthWorkspace W.shift) [0..])
  ++
            [
              ((modm, xK_BackSpace), kill)
            -- Navigation
            , ((mod1Mask, xK_j), windowSwap D True >> windows W.focusDown)
            , ((mod1Mask, xK_k), windowSwap U True >> windows W.focusUp)
            , ((mod1Mask, xK_m), sendMessage MasterOverLayToggleFocus)
            -- Misc
            , ((modm, xK_BackSpace), kill)
            -- GridSelecet
            -- Toggle left / right column width 
            , ((modm, xK_semicolon), sendMessage (middleColumnModifyId {
                                                         modifySplitRatio = \x -> if x >= 0.25 then (0.25 - 1 * 0.04) else (0.25 + 2 * 0.04 )}))
            -- Resize left / right column width individually
            , ((mod1Mask, xK_i), sendMessage IncrementLeftColumnContainerWidth)
            , ((mod1Mask, xK_u), sendMessage DecrementLeftColumnContainerWidth)
            , ((mod1Mask, xK_d), sendMessage IncrementRightColumnContainerWidth)
            , ((mod1Mask, xK_h), sendMessage DecrementRightColumnContainerWidth)
            -- Modify column pin count
            , ((modm , xK_period), sendMessage IncrementLeftColumnContainer)
            , ((modm , xK_y), sendMessage IncrementRightColumnContainer)
            -- Modify master window count
            , ((modm, xK_comma ), sendMessage (IncMasterN 1)) -- %! Increment the number of windows in the master area
            , ((modm, xK_apostrophe), sendMessage (IncMasterN (-1))) -- %! Deincrement the number of windows in the master area
            -- Swop column positions
            , ((modm .|. shiftMask, xK_i), sendMessage SwopLeftColumn)
            , ((modm .|. shiftMask, xK_d), sendMessage SwopRightColumn)
            , ((mod1Mask, xK_r), submap . M.fromList $ [
                  (singleKey xK_c, sendMessage ResetColumn)
                , (singleKey xK_w, sendMessage ResetColumnContainerWidth)
                , (singleKey xK_s, sendMessage ResetColumnContainer)
              ]
              )
            , ((modm, xK_s), submap . M.fromList $ specialKeyMappings 
              )
            , ((modm, xK_n), submap . M.fromList $ [ -- navigate to program
                (singleKey xK_b, do
                    win' <- findWindowsByClass "Chromium"
                    when (length win' > 0)
                      (windows $ W.focusWindow $ head win')
                )
              , (singleKey xK_e, do
                    win' <- findWindowsByClass "Emacs"
                    when (length win' > 0)
                      (windows $ W.focusWindow $ head win')
                )
              , (singleKey xK_m, do
                    win' <- findWindowsByClass "Thunderbird"
                    when (length win' > 0)
                      (windows $ W.focusWindow $ head win')
                )
              ])
            -- Modify main column width
            , ((modm, xK_i), sendMessage Shrink)
            , ((modm, xK_d), sendMessage Expand)
            -- Message sending
            -- Rofi
            , ((modm .|. shiftMask, xK_p), spawn "rofi -show-icons -combi-modi run -show combi -modi combi")
            , ((modm, xK_p),               spawn "rofi -show-icons -combi-modi drun -show combi -modi combi")
            , ((modm .|. shiftMask, xK_w), spawn "rofi -show-icons -combi-modi window -show combi -modi combi")
            , ((modm, xK_v), spawn "rofi -modi 'clipboard:greenclip print' -show clipboard -run-command '{cmd}'")
            -- Sticky window
            , ((mod1Mask, xK_l), do
                withFocused (\f -> windows $ W.float f (W.RationalRect (6/10) (1/4) (1/3) (1/3)))
                windows copyToAll
              ) -- @@ Make focused window always visible
            , ((mod1Mask, xK_c),  killAllOtherCopies) -- @@ Toggle window state back
            -- Focus previous window
            , ((modm, xK_b), nextMatch History (return True))
            -- Float window
            , ((modm, xK_x), withFocused (\f -> windows $ W.float f (W.RationalRect (6/10) (1/4) (1/3) (1/3))))
            --
            , ((modm, xK_c), submap . M.fromList $ -- focus specific window and swop it with master -- TODO refactor to use WindowPositon
                fmap
                  (\(c, i) ->
                    (singleKey (windowSelection c i), sendMessage $
                      case c of
                        Column.Left -> SwopLeft i
                        Column.Right -> SwopRight i
                        ))
                  $ concat [
                      fmap ((,) Column.Left) [1,2,3,4,5,6,7,8]
                    , fmap ((,) Column.Right) [1,2,3,4,5,6,7,8]                        ]
            )
            , ((modm, xK_g), submap . M.fromList $ -- focus specific window -- TODO refactor to use WindowPosition
                fmap
                  (\(c, i) ->
                    (singleKey (windowSelection c i), sendMessage $
                      case c of
                        Column.Left -> FocusLeft i
                        Column.Right -> FocusRight i
                        ))
                  $ concat [
                      fmap ((,) Column.Left) [1,2,3,4,5,6,7,8]
                    , fmap ((,) Column.Right) [1,2,3,4,5,6,7,8]                        ]
            )
            , ((modm, xK_f), submap . M.fromList $ -- focus specic window and swop it with 1/2/3 nth window
                fmap
                  (\(w, wi) ->
                      (singleKey w, submap . M.fromList $ fmap
                        (\(c, i) ->
                          (singleKey (windowSelection c i), sendMessage $ SwopTo (WindowPosition i c Up) (WindowPosition wi Middle Up)))
                        $ concat [
                            fmap ((,) Column.Left)  [1,2,3,4,5,6,7,8]
                          , fmap ((,) Column.Right) [1,2,3,4,5,6,7,8]
                          ]
                      )
                  )
                  [(w1, 1), (w2, 2), (w3, 3)]
            )
            --
            , ((modm, xK_w), submap . M.fromList $
                [ (singleKey xK_a, withNthWorkspace W.greedyView 0)
                , (singleKey xK_o, withNthWorkspace W.greedyView 1)
                , (singleKey xK_e, withNthWorkspace W.greedyView 2)
                , (singleKey xK_u, withNthWorkspace W.greedyView 3)
                , (singleKey xK_h, withNthWorkspace W.greedyView 4)
                , (singleKey xK_t, withNthWorkspace W.greedyView 4)
                , (singleKey xK_n, withNthWorkspace W.greedyView 6)
                , (singleKey xK_s, withNthWorkspace W.greedyView 7)
                ]
            )
            -- Dynamic workspaces
            , ((modm .|. shiftMask, xK_r), renameWorkspace def)
            , ((modm .|. shiftMask, xK_a), addWorkspacePrompt def)
            -- Workspace navigation
            --, ((modm, xK_e), prevWS)
            --, ((modm, xK_u), nextWS)
            , ((modm, xK_e), moveTo Prev NonEmptyWS)
            , ((modm, xK_u), moveTo Next NonEmptyWS)
            -- Misc
            , ((modm, xK_slash), spawn "qterminal")
            , ((modm, xK_l), withFocused $ windows . W.sink)
            , ((mod1Mask, xK_F3), spawn "amixer -q sset Master 5%-")
            , ((mod1Mask, xK_F4), spawn "amixer -q sset Master 5%+")
            , ((mod1Mask, xK_F2), spawn "amixer -q sset Master toggle")
            --, ((modm .|. shiftMask, xK_r), devWorkspacePrompt)
            --, ((modm, (fromIntegral button3)), (\w -> focus w >> Flex.mouseResizeWindow w))
            , ((modm, xK_backslash), windows W.focusDown)
            ]

w1, w2, w3 :: KeySym
windowSelection  :: Column -> Int -> KeySym
w1 = xK_f
w2 = xK_d
w3 = xK_b
windowSelection Column.Left 1 = xK_u
windowSelection Column.Left 2 = xK_e
windowSelection Column.Left 3 = xK_o
windowSelection Column.Left 4 = xK_a
windowSelection Column.Left 5 = xK_p
windowSelection Column.Left 6 = xK_period
windowSelection Column.Left 7 = xK_comma
windowSelection Column.Left 8 = xK_apostrophe
windowSelection Column.Right 1 = xK_h
windowSelection Column.Right 2 = xK_t
windowSelection Column.Right 3 = xK_n
windowSelection Column.Right 4 = xK_s
windowSelection Column.Right 5 = xK_g
windowSelection Column.Right 6 = xK_c
windowSelection Column.Right 7 = xK_r
windowSelection Column.Right 8 = xK_l
windowSelection _ _ = xK_u

singleKey :: b -> (KeyMask, b)
singleKey = (,) noModMask

devSessionPrompt :: X ()
devSessionPrompt = spawn "rofi -normal-window -show fb -modi fb:~/Scripts/rofi/xmonadRofi.sh"

showClipboardApp :: X ()
showClipboardApp = spawn "~/ScriptsVcs/showClipboard.sh"

devWorkspacePrompt :: X ()
devWorkspacePrompt = do
  x <- liftIO $ readProcess "rofi" ["-normal-window", "-show fb -modi fb:~/Scripts/rofi/xmonadSpace.sh"] ""
  renameWorkspaceByName x

rearrangeWindows' :: (Int -> W.Stack Window -> W.Stack Window) -> X [Window] -> X ()
rearrangeWindows' f f' =
  (\ws -> fmap (\w' -> elemIndex w' (W.integrate' ws)))
    <$> (get >>= return . W.stack . W.workspace . W.current . windowset)
    <*> (f')
  >>= \case
    (Just x:_) -> windows . W.modify' $ f x
    _ -> pure ()

rearrangeWindows :: X ()
rearrangeWindows = do
  rearrangeWindows' (swopStackElements 0) (findWindowsByClass "Emacs")
  rearrangeWindows' (swopStackElements 2) (findWindowsInCurrentWorkspaceByTitle "ranger" )
  rearrangeWindows' (swopStackElements 3) (findWindowsInCurrentWorkspaceByTitlePrefix "magit")

specialKeyMappings = [
                (singleKey xK_b, sendMessage ToggleStruts)
              , (singleKey xK_f, sendMessage $ Toggle FULL)
              , (singleKey xK_z, devSessionPrompt)
              --, (singleKey xK_p, updatePointer (0.5, 0.5) (0, 0))
              , (singleKey xK_c, showClipboardApp)
              , (singleKey xK_g, goToSelected def)
              , ((shiftMask, xK_g), bringSelected def)
              , (singleKey xK_p, spawn "xdotool type \"$(xclip -out)\"")
              , (singleKey xK_t, spawn "emacsclient -c /home/chris/Projects/OrgModeTest/theGreat/theGreatTodo.org")
              , (singleKey xK_h, spawn "rofi -normal-window -show fb -modi fb:~/Scripts/rofi/envs/haskell/rofi.sh")
              -- programs
              , (singleKey xK_e, spawn "emacsclient -c")
              , (singleKey xK_v, spawn "lxterminal -e nvim")
              , (singleKey xK_r, rearrangeWindows)
              , (singleKey xK_s, sendMessage ToggleMasterColumnSplit)
              ]
