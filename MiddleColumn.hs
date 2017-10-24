{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module MiddleColumn where

import           Control.Monad
import           XMonad
import qualified XMonad.StackSet as W
import FocusWindow

import Data.List (sortBy)
import Data.Function (on)
import Text.Read
import Debug.Trace

traceTraceShowId :: Show a => String -> a -> a
traceTraceShowId x = traceShow x . traceShowId

data ModifySideContainer = IncrementLeftColumnContainer | IncrementRightColumnContainer | ResetColumnContainer deriving Typeable
instance Message ModifySideContainer

data ModifySideContainerWidth = IncrementLeftColumnContainerWidth | IncrementRightColumnContainerWidth | DecrementLeftColumnContainerWidth | DecrementRightColumnContainerWidth | ResetColumnContainerWidth deriving Typeable
instance Message ModifySideContainerWidth

data FocusSideColumnWindow n = FocusLeft n | FocusRight n deriving Typeable
instance Message (FocusSideColumnWindow Int)

data SwopSideColumnWindow n = SwopLeft n | SwopRight n deriving Typeable
instance Message (SwopSideColumnWindow Int)

data SwopSideColumn = SwopLeftColumn | SwopRightColumn | ResetColumn deriving (Show, Typeable)
instance Message (SwopSideColumn)

instance Read SwopSideColumn where
  readPrec     = return (ResetColumn)
  readListPrec = readListPrecDefault

getMiddleColumnSaneDefault :: Int -> Float -> (Float,Float,Float) -> MiddleColumn a
getMiddleColumnSaneDefault mColumnCount mTwoRatio mThreeRatio = MiddleColumn {
    splitRatio = 0.25
  , middleColumnCount = mColumnCount
  , deltaIncrement = 0.04
  , middleTwoRatio = mTwoRatio
  , middleThreeRatio = mThreeRatio
  , leftContainerWidth = Nothing
  , rightContainerWidth = Nothing
  , leftContainerCount = 0
  , rightContainerCount = 0
  , columnSwop = ResetColumn
  }
  

data MiddleColumnEnum = LColumn | MColumn | RColumn

-- Example: MiddleColumn 0.25 1 0.040 0.25
data MiddleColumn a = MiddleColumn {
  splitRatio        :: Float, -- width ratio of side columns
  middleColumnCount :: Int, -- number of windows in middle column
  deltaIncrement    :: Float,
  middleTwoRatio    :: Float, -- ratio of window height when two windows are in the middle column,
  middleThreeRatio    :: (Float,Float,Float), -- ratio of window height when two windows are in the middle column,
  leftContainerWidth :: Maybe (Float),
  rightContainerWidth :: Maybe (Float),
  leftContainerCount :: Int,
  rightContainerCount :: Int,
  columnSwop :: SwopSideColumn
  } deriving (Show, Read)


-- If zero then return no rectangles
splitVerticallyFixed :: Int -> Rectangle -> [Rectangle]
splitVerticallyFixed 0 _ = []
splitVerticallyFixed c r = splitVertically c r

xAccumulateRecatangle :: [Rectangle] -> [Rectangle]
xAccumulateRecatangle ([]) = []
xAccumulateRecatangle (r1:[]) = [r1]
xAccumulateRecatangle (r1:r2:[]) = r1 : [r2 {rect_x = floor $ (fromIntegral $ rect_x r1) + (fromIntegral $ rect_width r1 :: Float)}]
xAccumulateRecatangle (r1:r2:r3) = do
  let [ar1, ar2] = xAccumulateRecatangle (r1 : [r2])
  ar1 : (xAccumulateRecatangle $ ar2 : r3)

splitHorizontallyByRatios :: [Float] -> Rectangle -> [Rectangle]
splitHorizontallyByRatios ratios mainR@(Rectangle _ _ w _) = do
  let widthSet = fmap (\ratio -> mainR { rect_width = floor $ fromIntegral w * ratio}) ratios
  xAccumulateRecatangle widthSet where

splitVerticallyByRatios :: [Float] -> Rectangle -> [Rectangle]
splitVerticallyByRatios f = fmap mirrorRect . splitHorizontallyByRatios f . mirrorRect

getRecsWithSideContainment :: Rectangle -> Rectangle -> Int -> Int ->  Int -> ([Rectangle], [Rectangle])
-- Show window on left if it's the only window
getRecsWithSideContainment lRec _ 0 0 1 = ([lRec], [])
-- divide equally between left and right
getRecsWithSideContainment lRec rRec 0 0 totalCount =
  ( splitVerticallyFixed lCount lRec
  , reverse (splitVerticallyFixed rCount rRec)
  ) where
    (lCount, rCount) = splitDiscrete (totalCount)
    splitDiscrete a = (b, a - b) where
      b = (quot a 2)
-- divide with a max count on left or right
getRecsWithSideContainment lRec rRec leftMax rightMax totalCount = (\(i, j) -> (i, reverse j)) $ if (leftMax > 0)
  then ( splitVerticallyFixed leftMax lRec
       , splitVerticallyFixed (totalCount - leftMax) rRec
       )
  else ( splitVerticallyFixed (totalCount - rightMax) lRec
       , splitVerticallyFixed rightMax rRec
       )

columnSwops :: MiddleColumn a -> [Rectangle] -> [Rectangle]
columnSwops l (middleRec:leftRec:rightRec:[]) = case (columnSwop l) of
  ResetColumn -> [middleRec,leftRec,rightRec]
  SwopLeftColumn -> [leftRec,middleRec, rightRec]
  SwopRightColumn -> [rightRec,leftRec,middleRec]
columnSwops _ r = r

instance LayoutClass MiddleColumn a where
  description _ = "MiddleColumn"
  doLayout l r s   = do
    let mcc = middleColumnCount l
    let lContainerCount = leftContainerCount l
    let rContainerCount = rightContainerCount l
    let sideColumnWindowCount = (length $ W.integrate s) - mcc
    let l'  = if (lContainerCount > 0) then
            l { leftContainerCount = lcc , rightContainerCount = - (lcc) }
          else if (rContainerCount > 0) then
            l { leftContainerCount = - (rcc) , rightContainerCount = rcc }
          else l
            where
              lcc = min sideColumnWindowCount lContainerCount
              rcc = min sideColumnWindowCount rContainerCount
    return (pureLayout l' r s, Just l')
  pureLayout l screenRec s = zip ws (recs $ length ws) where
    mcc = middleColumnCount l
    mctRatio = middleTwoRatio l
    mc3Ratio = middleThreeRatio l
    lContainerCount = leftContainerCount l
    rContainerCount = rightContainerCount l
    (middleRec:leftRec:rightRec:[]) = mainSplit l screenRec
    ws = W.integrate s
    middleRecs = 
      -- If there are two windows in the "middle column", make the larger window the master
      if (mcc == 2) then
        reverse . sortBy (compare `on` rect_height) $ (\(m1,m2) -> [m1,m2]) $ splitVerticallyBy mctRatio middleRec
      else if (mcc == 3) then
        reverse . sortBy (compare `on` rect_height) $ splitVerticallyByRatios ((\(m1,m2,m3) -> [m1,m2,m3]) mc3Ratio) middleRec
      else
        splitVertically mcc middleRec
    recs wl = middleRecs ++ leftInnerRecs ++ rightInnerRecs where
      (leftInnerRecs, rightInnerRecs) = getRecsWithSideContainment leftRec rightRec lContainerCount rContainerCount ((wl) - mcc)
  pureMessage l m = msum [
    fmap resize     (fromMessage m),
    fmap incmastern (fromMessage m),
    fmap incSideContainer (fromMessage m),
    fmap incSideContainerWidth (fromMessage m),
    fmap columnSwopAbc (fromMessage m)
    ]
    where
      widthInc = 0.02
      sRatio = splitRatio l
      mcc = middleColumnCount l
      leftCount = leftContainerCount l
      rightCount = rightContainerCount l
      -- count
      incSideContainer IncrementLeftColumnContainer = l
        { leftContainerCount = leftCount + 1, rightContainerCount = rightCount - 1}
      incSideContainer IncrementRightColumnContainer = l
        { leftContainerCount = leftCount - 1, rightContainerCount = rightCount + 1}
      incSideContainer ResetColumnContainer = l
        { leftContainerCount = 0, rightContainerCount = 0}
      -- width
      incSideContainerWidth IncrementLeftColumnContainerWidth = l
        { leftContainerWidth = Just $ maybe (splitRatio l) (+ widthInc) (leftContainerWidth l) }
      incSideContainerWidth IncrementRightColumnContainerWidth = l
        { rightContainerWidth = Just $ maybe (splitRatio l) (+ widthInc) (rightContainerWidth l) }
      incSideContainerWidth DecrementLeftColumnContainerWidth = l
        { leftContainerWidth = Just $ maybe (splitRatio l) (flip (-) widthInc) (leftContainerWidth l) }
      incSideContainerWidth DecrementRightColumnContainerWidth = l
        { rightContainerWidth = Just $ maybe (splitRatio l) (flip (-) widthInc) (rightContainerWidth l) }
      incSideContainerWidth ResetColumnContainerWidth = l
        { leftContainerWidth = Nothing, rightContainerWidth = Nothing}
      -- column swops
      columnSwopAbc cs = l { columnSwop = cs}
      resize Expand = l {splitRatio = (min 0.5 $ sRatio + 0.04)}
      resize Shrink = l {splitRatio = (max 0 $ sRatio - 0.04)}
      incmastern (IncMasterN x) = l { middleColumnCount = max 0 (mcc+x) }
  handleMessage l m = do
    let leftWindowOffset = traceTraceShowId "leftWindowOffset:" $ (middleColumnCount l - 1)
    -- Not sure how to avoid this nested case.
    case (fromMessage m :: Maybe (FocusSideColumnWindow Int)) of
      (Just (FocusLeft n)) -> do
        windows $ focusWindow $ (traceTraceShowId "FocusLeft:" n) + leftWindowOffset
        return Nothing
      (Just (FocusRight n)) -> do
        windows $ focusWindow $ negate $ (traceTraceShowId "FocusRight:" n)
        return Nothing
      Nothing ->
        case (fromMessage m :: Maybe (SwopSideColumnWindow Int)) of
        (Just (SwopLeft n)) -> do
          swopWindowToMaster $ n + leftWindowOffset
          return Nothing
        (Just (SwopRight n)) -> do
          windows $ focusWindow (negate n)
          swopWindowToMaster $ negate n
          return Nothing
        Nothing -> return $ pureMessage l m

mainSplit :: MiddleColumn a -> Rectangle -> [Rectangle]
mainSplit z (Rectangle sx sy sw sh) = columnSwops z [m, l, r]
  where
    f = splitRatio z
    splitWLeft = floor $ fromIntegral sw * (maybe f id (leftContainerWidth z))
    splitWRight = floor $ fromIntegral sw * (maybe f id (rightContainerWidth z))
    splitWMiddle = sw - (splitWLeft) - (splitWRight)
    l = Rectangle sx sy splitWLeft sh
    m = Rectangle (sx + fromIntegral splitWLeft) sy (splitWMiddle) sh
    r = Rectangle ((fromIntegral sw) - (fromIntegral splitWRight)) sy splitWRight sh
