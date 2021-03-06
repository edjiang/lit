module Macro where

import Text.Parsec
import Text.Parsec.String
import Text.Regex
import System.IO

{-
 - TODO:
 - trim \n after a code chunk
 -
 - NOTICE: This file is not actually contribute to the repo, see Parse.hs
 -}

build outputDir files = 
    let outputPaths = map (\f -> outputDir ++ (fileNameFromPath f)) files 
    in mapM readFile files >>= (sequence . zipWith process outputPaths) >> return ()

process out src =
    case (parse entire "" src) of 
    Left err -> putStrLn (show err) >> (return ())
    Right result -> writeFile out result >> (return ())

fileNameFromPath :: String -> String
fileNameFromPath path =
    let r = mkRegex "(\\w+\\.\\w+)\\.lit$"
        m = matchRegex r path 
    in case m of 
        Just (fst:rest) -> fst
        Nothing -> ""

entire = do
    cs <- manyTill chunk eof
    return $ concat (filter (\s -> s /= "") cs)

chunk = (try def) <|> skipLine

def = do
    (indent, header) <- title
    nls <- many newline
    lines <- manyTill (grabNL <|> defLine indent) (endDef indent)
    return (header ++ nls ++ (concat lines))

defLine indent = do
    (string indent) 
    line <- takeLine 
    case (endDef indent) of 
        _ -> return line

-- pretty fucking ugly code 
-- probably doesn't need a try, since only one char
grabNL = do
    nl <- try newline
    return $ nl:""

endDef indent = try (skipMany newline >> (notFollowedBy (string indent) <|> ((lookAhead title) >> parserReturn ())))


skipLine :: Parser String
skipLine = many (noneOf "\n\r") >> eol >> return ""

takeLine :: Parser String
takeLine = do 
    many <- many (noneOf "\n\r")
    last <- eol
    return $ many ++ [last]

-- Pre: Assumes that parser is looking at a fresh line with a macro defn
-- Post: Returns (indent, macro-name@line-no\n)
title :: Parser (String, String)
title = do
    pos <- getPosition
    indent <- many ws
    name <- between openDelim closeDelim (many notDelim)
    eol
    return $ (indent, name ++ "@" ++ (show (sourceLine pos)) ++ "\n")

notDelim = noneOf ">="
openDelim = string "<<"
closeDelim = string ">>="
ws = space <|> char '\t'  -- consume a whitespace char

eol = char '\n' <|> char '\r'
