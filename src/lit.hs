module Main where

import System.Console.GetOpt
import System.Environment
import System.Directory (doesDirectoryExist)
import System.IO
import System.Exit
import Control.Applicative

import Processing
import Poll

data Options = Options  { optCodeDir  :: String 
                        , optDocsDir  :: String
                        , optCss      :: Maybe String
                        , optCode     :: Bool
                        , optHtml     :: Bool
                        , optMarkdown :: Bool
                        , optWatch    :: Bool
                        }

startOptions :: Options
startOptions = Options  { optCodeDir  = "./"
                        , optDocsDir  = "./"
                        , optCss      = Nothing
                        , optCode     = False
                        , optHtml     = False
                        , optMarkdown = False
                        , optWatch    = False
                        }

options :: [ OptDescr (Options -> IO Options) ]
options = 
    [ Option  "h" ["html"]
       (NoArg (\opt -> return opt { optHtml = True }))
       "Generate html"

    , Option "m" ["markdown"]
       (NoArg (\opt -> return opt { optMarkdown = True }))
       "Generate markdown"

    , Option "c" ["code"]
       (NoArg (\opt -> return opt { optCode = True }))
       "Generate code by file extension"

    , Option "" ["css"]
       (ReqArg
           (\arg opt -> return opt { optCss = Just arg })
           "FILE")
       "Specify a css file for html generation"

    , Option "" ["docs-dir"]
       (ReqArg
           (\arg opt -> return opt { optDocsDir = arg })
           "DIR")
       "Directory for generated docs"

    , Option "" ["code-dir"]
       (ReqArg
           (\arg opt -> return opt { optCodeDir = arg })
           "DIR")
       "Directory for generated code"

    , Option "w" ["watch"]
       (NoArg
           (\opt -> return opt { optWatch = True}))
       "Watch for file changes, automatically run lit"
 
    , Option "v" ["version"]
       (NoArg
           (\_ -> do
               hPutStrLn stderr "Version 0.01"
               exitWith ExitSuccess))
       "Print version"
 
    , Option "" ["help"]
       (NoArg
           (\_ -> do
               prg <- getProgName
               hPutStrLn stderr (usageInfo header options)
               exitWith ExitSuccess))
       "Display help"
    ]

header = "Usage: lit OPTIONS... FILES..."

main = do
    args <- getArgs
 
    -- Parse options, getting a list of option actions
    let (actions, files, errors) = getOpt Permute options args
    
    -- Here we thread startOptions through all supplied option actions
    opts <- foldl (>>=) (return startOptions) actions
 
    let Options { optCodeDir  = codeDir
                , optDocsDir  = docsDir
                , optMarkdown = markdown
                , optCode     = code
                , optHtml     = html
                , optCss      = mCss
                , optWatch    = watching
                } = opts 

    codeDirCheck <- doesDirectoryExist codeDir
    docsDirCheck <- doesDirectoryExist docsDir

    let htmlPipe = if html     then [Processing.htmlPipeline docsDir] else []
        mdPipe   = if markdown then [Processing.mdPipeline   docsDir] else []
        codePipe = if code     then [Processing.codePipeline codeDir] else []
        pipes = htmlPipe ++ mdPipe ++ codePipe 
        maybeWatch = if watching then Poll.watch else mapM_
        errors'  = if codeDirCheck then [] else ["Directory: " ++ codeDir ++ " does not exist\n"]
        errors'' = if docsDirCheck then [] else ["Directory: " ++ docsDir ++ " does not exist\n"]
        allErr = errors ++ errors' ++ errors''

    if allErr /= [] || (not html && not code && not markdown)
        then hPutStrLn stderr ((concat allErr) ++ header) 
        else (maybeWatch (Processing.build mCss pipes)) files
