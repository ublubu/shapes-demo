import qualified Graphics.UI.SDL.Video as SDL.V
import qualified Graphics.UI.SDL.Enum as SDL.E
import qualified Graphics.UI.SDL.Types as SDL.T
import qualified Graphics.UI.SDL.Basic as SDL.B
import qualified Graphics.UI.SDL.Timer as SDL.Timer
import qualified Graphics.UI.SDL.Event as SDL.Event
import qualified Graphics.UI.SDL.Image as Image
import Control.Monad
import Control.Monad.State hiding (state)
import Data.Bits
import Data.List.Zipper
import Foreign.C.String
import Foreign.C.Types
import Foreign.Marshal.Alloc
import Foreign.Marshal.Utils
import Foreign.Ptr
import Foreign.Storable
import GHC.Word
import SDL.Draw
import SDL.Error
import SDL.Event
import SDL.Init
import SDL.Loading
import SDL.Geometry
import Utils.Utils
import Game
import Grid
import SlidingGrid
import SmoothSlidingGrid

---- Config ----

windowTitle :: String
windowTitle = "Tile Rider"

screenWidth :: CInt
screenWidth = 640

screenHeight :: CInt
screenHeight = 480

fullWindow :: SDL.T.Rect
fullWindow = SDL.T.Rect {
  SDL.T.rectX = 0,
  SDL.T.rectY = 0,
  SDL.T.rectW = screenWidth,
  SDL.T.rectH = screenHeight }

initialState :: World
initialState = World
  { gameOver = False
  , grid = fromRows [ [ SlidingTile ()
                      , EmptyTile
                      , FixedTile () ]
                    , [SlidingTile ()
                      , SlidingTile ()
                      , SlidingTile () ]
                    , [SlidingTile ()
                      , SlidingTile ()
                      , SlidingTile () ] ]
  , worldInput = InputState { mouseButtonDown = Nothing
                            , mousePosition = zero }}

---- Application ----

printMaybeTiles :: Show a => Maybe (TileZipper a) -> IO ()
printMaybeTiles mz = case mz of
  Nothing -> print mz
  Just z -> printTiles z

main :: IO ()
main = do
  initializeSDL [SDL.E.SDL_INIT_VIDEO] >>= catchRisky
  Image.imgInit [Image.InitPNG]

  setHint "SDL_RENDER_SCALE_QUALITY" "1" >>= logWarning
  window <- createWindow windowTitle screenWidth screenHeight >>= catchRisky
  renderer <- createRenderer window (-1) [SDL.E.SDL_RENDERER_ACCELERATED] >>= catchRisky

  asset <- loadTexture renderer "./assets/blop-nar.png" >>= catchRisky

  let inputSource = pollEvent `into` updateState
  let pollDraw = inputSource ~>~ drawState renderer fullWindow [asset]
  runStateT (runUntilComplete pollDraw) initialState

  freeAssets [asset]
  SDL.V.destroyRenderer renderer
  SDL.V.destroyWindow window
  SDL.B.quit
  Image.imgQuit

