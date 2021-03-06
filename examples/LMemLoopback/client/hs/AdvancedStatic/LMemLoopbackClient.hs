module Main where

import qualified LMemLoopbackService_Client as Client
import LMemLoopback_Types

import Thrift
import Thrift.Protocol.Binary
import Thrift.Server
import Thrift.Transport
import Thrift.Transport.Handle

import Control.Exception
import Data.Either
import Data.Int
import Data.List
import Data.Maybe
import Data.Time
import Data.Text.Lazy
import Data.Vector
import Network
import System.Exit
import System.Random
import Text.Printf

getRight           :: Either left right -> right
getRight (Right x) = x

lMemLoopbackCPU :: [Int32] -> [Int32] -> [Int32]
lMemLoopbackCPU [] []         = []
lMemLoopbackCPU (a:inA) (b:inB) = (a + b) : (lMemLoopbackCPU (inA) (inB) )

check :: [Int32] -> [Int32] -> Int -> Int -> [Int]
check [] [] start end = []
check (x:outDFE) (y:outCPU) start end
	| (x == y)		=  check outDFE outCPU (start+1) end
	| otherwise 	= (start) : check outDFE outCPU (start+1) end

printErrors :: [Int] -> [Int32] -> [Int32] -> String -> String
printErrors [] xs ys output                 = output
printErrors (i:is) xs ys output     = printErrors is xs ys (output Data.List.++ "Output data @ " Data.List.++ (show i) Data.List.++ " = " Data.List.++ (show (xs!!i))  Data.List.++ " (expected " Data.List.++ (show (ys!!i))  Data.List.++ ")\n")

main = do
    startTime <- getCurrentTime
    startDFETime <- getCurrentTime
    
    -- Make socket
    transport <- hOpen ("localhost", PortNumber 9090)

    -- Wrap in a protocol
    let protocol = BinaryProtocol transport

    -- Create a client to use the protocol encoder
    let client = (protocol, protocol)
    stopTime <- getCurrentTime
    putStrLn ("Creating a client and opening connection:\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Generate input data
    startTime <- getCurrentTime
    let size = 384
    let sizeBytes = size * 4
    let inA = [0 .. (size-1)]
    let inB = [size - a | a <- inA]
    stopTime <- getCurrentTime
    putStrLn ("Generating input data:\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Initialize maxfile
    startTime <- getCurrentTime
    e <- try (Client.lMemLoopback_init client) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let maxfile = getRight e
    stopTime <- getCurrentTime
    putStrLn ("Initializing maxfile:\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Load DFE
    startTime <- getCurrentTime
    e <- try (Client.max_load client maxfile (pack "*")) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let engine = getRight e
    stopTime <- getCurrentTime
    putStrLn ("Loading DFE:\t\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Allocate and send input streams to server
    startTime <- getCurrentTime
    e <- try (Client.malloc_int32_t client (fromIntegral size)) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let address_inA = getRight e

    e <- try (Client.send_data_int32_t client address_inA (fromList inA)) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()

    e <- try (Client.malloc_int32_t client (fromIntegral size)) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let address_inB = getRight e

    e <- try (Client.send_data_int32_t client address_inB (fromList inB)) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
        
    stopTime <- getCurrentTime
    putStrLn ("Sending input data:\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Allocate memory for output stream on server
    startTime <- getCurrentTime

    e <- try (Client.malloc_int32_t client (fromIntegral size)) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let address_dataOut = getRight e

    stopTime <- getCurrentTime
    putStrLn ("Allocating memory for output stream on server:\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Writing to LMem 
    startTime <- getCurrentTime
    let actions_lmemA = LMemLoopback_writeLMem_actions_t_struct (Just (fromIntegral 0)) (Just (fromIntegral sizeBytes)) (Just (fromIntegral address_inA))
    e <- try (Client.send_LMemLoopback_writeLMem_actions_t client actions_lmemA) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let address_actions_lmemA = getRight e

    e <- try (Client.lMemLoopback_writeLMem_run client engine address_actions_lmemA) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()

    let actions_lmemB = LMemLoopback_writeLMem_actions_t_struct (Just (fromIntegral sizeBytes)) (Just (fromIntegral sizeBytes)) (Just (fromIntegral address_inB))
    e <- try (Client.send_LMemLoopback_writeLMem_actions_t client actions_lmemB) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let address_actions_lmemB = getRight e

    e <- try (Client.lMemLoopback_writeLMem_run client engine address_actions_lmemB) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()

    stopTime <- getCurrentTime
    putStrLn ("Writing to LMem:\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Action default
    startTime <- getCurrentTime
    let action = LMemLoopback_actions_t_struct (Just (fromIntegral size))
    e <- try (Client.send_LMemLoopback_actions_t client action) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let address_action = getRight e

    e <- try (Client.lMemLoopback_run client engine address_action) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()

    stopTime <- getCurrentTime
    putStrLn ("LMemLoopback time:\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Reading from LMem
    startTime <- getCurrentTime
    let actions_lmemRead = LMemLoopback_readLMem_actions_t_struct (Just (fromIntegral (2 * sizeBytes))) (Just (fromIntegral sizeBytes)) (Just (fromIntegral address_dataOut))
    e <- try (Client.send_LMemLoopback_readLMem_actions_t client actions_lmemRead) :: IO (Either SomeException Int64)
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    let address_actions_lmemRead = getRight e

    e <- try (Client.lMemLoopback_readLMem_run client engine address_actions_lmemRead) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()

    stopTime <- getCurrentTime
    putStrLn ("Reading from LMem:\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Unload DFE
    startTime <- getCurrentTime
    e <- try (Client.max_unload client engine) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    stopTime <- getCurrentTime
    putStrLn ("Unloading DFE:\t\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Get output stream from server
    startTime <- getCurrentTime
    dataOutDFE <- Client.receive_data_int32_t client address_dataOut (fromIntegral size)
    stopTime <- getCurrentTime
    putStrLn ("Getting output stream:\t(size = " Data.List.++ (show (size * 32)) Data.List.++ " bit)\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Free allocated memory for streams on server
    startTime <- getCurrentTime
    e <- try (Client.free client address_inA) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    e <- try (Client.free client address_inB) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    e <- try (Client.free client address_dataOut) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()
    
    stopTime <- getCurrentTime
    putStrLn ("Freeing allocated memory for streams on server:\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Free allocated maxfile data
    startTime <- getCurrentTime
    e <- try (Client.lMemLoopback_free client) :: IO (Either SomeException ())
    case e of
        Left ex -> putStrLn $ "Caught exception: " Data.List.++ show ex
        Right ex -> return ()

    -- Close!
    startTime <- getCurrentTime
    tClose transport
    stopTime <- getCurrentTime
    putStrLn ("Closing connection:\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    stopTime <- getCurrentTime
    putStrLn ("DFE LMemLoopback total time:\t\t\t" Data.List.++ (show (diffUTCTime stopTime startDFETime)))

    -- CPU Output
    startTime <- getCurrentTime
    let dataOutCPU = lMemLoopbackCPU inA inB
    stopTime <- getCurrentTime
    putStrLn ("CPU LMemLoopback total time::\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    -- Checking results
    startTime <- getCurrentTime
    let errors = check (toList dataOutDFE) dataOutCPU 0 (fromIntegral size)
    stopTime <- getCurrentTime
    putStrLn ("Checking results:\t\t\t\t" Data.List.++ (show (diffUTCTime stopTime startTime)))

    if ((Data.List.length errors)== 0)
	then putStrLn ("Test successful!")
        else do putStr (printErrors errors (toList dataOutDFE) dataOutCPU [])
                putStrLn ("Test failed "  Data.List.++ show (Data.List.length errors)  Data.List.++ " times!")
                exitWith $ ExitFailure (-1)


