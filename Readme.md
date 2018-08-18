# XMonad Middle Column Layout (4k / Large monitor friendly)


## Installation (these instrucitons might be quite out of date since my latest changes!)

    cd ~/.xmonad
    mkdir -p lib
    cd lib
    git clone https://github.com/chrissound/XMonadLayouts .

**~/.xmonad/xmonad-conf.cabal**

```
  -- Initial xmonad-conf.cabal generated by cabal init.  For further
  -- documentation, see http://haskell.org/cabal/users-guide/

  name:                xmonad-conf
  version:             0.1.0.0
  -- synopsis:
  -- description:
  author:              Michiel Derhaeg
  maintainer:          derhaeg.michiel@gmail.com
  -- copyright:
  -- category:
  build-type:          Simple
  cabal-version:       >=1.10

  executable xmonad-x86_64-linux
    main-is:             xmonad.hs
    other-modules:
                        FocusWindow
                        , MiddleColumn
                        , WindowColumn
    -- other-extensions:
    build-depends:       base
                       , xmonad
                       , xmonad-contrib
                       , mtl
                       , containers
                       , process
                       , lens
    hs-source-dirs:      lib
    default-language:    Haskell2010
    ghc-options: -O2
```

**~/.xmonad/stack.yaml**
```
  local-bin-path: .

  resolver: lts-9.17

  packages:
  - '.'

  extra-deps: []

  flags: {}

  extra-package-dbs: []

  local-bin-path: .
```

**~/.xmonad/build**

```
  #!/bin/sh
  stack build --copy-bins
  mv /home/chris/.xmonad/xmonad-x86_64-linux $HOME/.local/bin/xmonad
```

This above will add the modules to be acccessible to your xmonad.hs

You then need to add the follow imports (and problaby more - have a look at my xmonad.hs):

    import           MiddleColumn
    import WindowColumn
    import WindowColumn as Column (Column(..))
    import XMonad.Actions.Submap

This helper function:

    defaultThreeColumn :: (Float, Float, Float)
    defaultThreeColumn = (0.15, 0.65, 0.2)

Add the layout to your config (by adding it within `layoutHook`), for example:

    layoutHook = desktopLayoutModifiers $ getMiddleColumnSaneDefault 2 0.15 defaultThreeColumn)

Now you just need to set the keybindings. I'm using a dvorak layout keyboard so these perhaps could be set to something else, but I've attached my entire xmonad.hs in this repo.


## Functionality:
- Main rectangle that is centered.
- Additional rows can be added in the middle column.
- Set a specific ratio between rows in the middle column can be set when there are two or three windows in the middle column.
- Pin the left or right to have a maximum amount windows. (I usuall have two left pinned windows). So for example you can pin the left column to only have a maximum of two windows, of which additional windows would accumulate on the right column.
- Swop the left or right column with the middle column.
- Swop or focus a window in the left or right column by the position in the column. For example you can focus the 3rd Window in the left column.
- Set the left or right column width individually. 

## Demo
[![Video demo](http://img.youtube.com/vi/e5GTCpzL3OY/0.jpg)](https://youtu.be/e5GTCpzL3OY "Video demo") 

## Example Screenshots
![MiddleColumn Example](https://i.imgur.com/QTLVBOp.jpg)
![MiddleColumn Example](http://i.imgur.com/m5EtcT1.jpg)
![MiddleColumn Example](http://i.imgur.com/uFD87WR.jpg)
![MiddleColumn Example 2](http://i.imgur.com/FyHpotk.jpg)
