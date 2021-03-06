// <copyright file="LMemLoopbackClient.cs" company="Maxeler">
// Copyright Maxeler. All rights reserved.
// </copyright>
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Sockets;

using com.maxeler.LMemLoopback;

using Thrift;
using Thrift.Protocol;
using Thrift.Transport;

/// <summary> 
/// LMemLoopback BasicStatic example
/// </summary>
internal class LMemLoopbackClient
{
    /// <summary> Checks if lMemLoopbackDfe and lMemLoopbackCpu return the same value 
    /// </summary>
    /// <param name = "dataOutDFE" > Data output from DFE </param>
    /// <param name = "dataOutCPU" > Data output from CPU </param>
    /// <param name = "size" > Size of array </param>
    /// <returns> Number of elements that doesn't match </returns>
    public static int Check(List<int> dataOutDFE, List<int> dataOutCPU, int size)
    {
        int status = 0;

        for (int i = 0; i < size; i++) 
        {
            if (dataOutDFE[i] != dataOutCPU[i]) 
            {
                Console.WriteLine("Output data @ {0} = {1} (expected {2})", i, dataOutDFE[i], dataOutCPU[i]);
                status++;
            }
        }

        return status;  
    }

    /// <summary> LMemLoopback on CPU </summary>
    /// <param name = "size"> Size of arrays </param>
    /// <param name = "inA"> First array </param>
    /// <param name = "inB"> Second array </param>
    /// <returns> Data output </returns>
    public static List<int> LMemLoopbackCPU(int size, List<int> inA, List<int> inB)
    {
        List<int> dataOut = new List<int>();

        for (int i = 0; i < size; i++)
        {
            dataOut.Add(inA[i] + inB[i]);
        }

        return dataOut;
    }

    /// <summary> LMemLoopback on DFE </summary>
    /// <param name = "size"> Size of arrays </param>
    /// <param name = "inA"> First array </param>
    /// <param name = "inB"> Second array </param>
    /// <returns> Data output </returns>
     public static List<int> LMemLoopbackDFE(int size, List<int> inA, List<int> inB)
     {
        Stopwatch sw = new Stopwatch();
        List<int> outData = new List<int>();
        int sizeBytes = size * 4;
        try
        {
            // Connect!
            var transport = new TSocket("localhost", 9090);
            var protocol = new TBinaryProtocol(transport);
            var client = new LMemLoopbackService.Client(protocol);
            transport.Open();

            // Initialize maxfile
            sw.Reset(); 
            sw.Start();
            var maxfile = client.LMemLoopback_init();
            sw.Stop();
            Console.WriteLine("Initializing maxfile:\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Load DFE
            sw.Reset(); 
            sw.Start();
            var engine = client.max_load(maxfile, "*");
            sw.Stop();
            Console.WriteLine("Loading DFE:\t\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Allocate and send input streams to server
            sw.Reset(); 
            sw.Start();
            var address_inA = client.malloc_int32_t(size);
            client.send_data_int32_t(address_inA, inA);

            var address_inB = client.malloc_int32_t(size);
            client.send_data_int32_t(address_inB, inB);
            sw.Stop();
            Console.WriteLine("Sending input data:\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Allocate memory for output stream on server
            sw.Reset(); 
            sw.Start();
            var address_outData = client.malloc_int32_t(size);
            sw.Stop();
            Console.WriteLine("Allocating memory for output stream on server:\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Writing to LMem
            sw.Reset(); 
            sw.Start();
            var actions = client.max_actions_init(maxfile, "writeLMem");
            client.max_set_param_uint64t(actions, "address", 0);
            client.max_set_param_uint64t(actions, "nbytes", sizeBytes);
            client.max_queue_input(actions, "cpu_to_lmem", address_inA, sizeBytes);

            client.max_run(engine, actions);

            actions = client.max_actions_init(maxfile, "writeLMem");
            client.max_set_param_uint64t(actions, "address", sizeBytes);
            client.max_set_param_uint64t(actions, "nbytes", sizeBytes);
            client.max_queue_input(actions, "cpu_to_lmem", address_inB, sizeBytes);

            client.max_run(engine, actions);
            sw.Stop();
            Console.WriteLine("Writing to LMem:\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Action default 
            sw.Reset(); 
            sw.Start();
            actions = client.max_actions_init(maxfile, "default");
            client.max_set_param_uint64t(actions, "N", size);

            client.max_run(engine, actions);
            sw.Stop();
            Console.WriteLine("LMemLoopback time:\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Reading from LMem
            sw.Reset(); 
            sw.Start();
            actions = client.max_actions_init(maxfile, "readLMem");
            client.max_set_param_uint64t(actions, "address", 2 * sizeBytes);
            client.max_set_param_uint64t(actions, "nbytes", sizeBytes);
            client.max_queue_output(actions, "lmem_to_cpu", address_outData, sizeBytes);        

            client.max_run(engine, actions);
            client.free(actions);
            sw.Stop();
            Console.WriteLine("Reading from LMem:\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Unload DFE
            sw.Reset(); 
            sw.Start();
            client.max_unload(engine);
            sw.Stop();
            Console.WriteLine("Unloading DFE:\t\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Get output stream from server
            sw.Reset(); 
            sw.Start();
            outData = client.receive_data_int32_t(address_outData, size);
            sw.Stop();
            Console.WriteLine("Getting output stream:\t(size = {0} bit)\t{1}s", size * 32, sw.Elapsed.TotalMilliseconds / 1000);

            // Free allocated memory for streams on server
            sw.Reset(); 
            sw.Start();
            client.free(address_inA);
            client.free(address_inB);
            client.free(address_outData);
            sw.Stop();
            Console.WriteLine("Freeing allocated memory for streams on server:\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Free allocated maxfile data
            sw.Reset(); 
            sw.Start();
            client.LMemLoopback_free();
            sw.Stop();
            Console.WriteLine("Freeing allocated maxfile data:\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

            // Close!
            sw.Reset(); 
            sw.Start();
            transport.Close();
            sw.Stop();
            Console.WriteLine("Closing connection:\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);
        }
        catch (SocketException e)
        {
            Console.WriteLine("Could not connect to the server: {0}.", e.Message);
            Environment.Exit(-1);
        }
        catch (Exception e)
        {
            Console.WriteLine("An error occured: {0}", e.Message);
            Environment.Exit(-1);
        }

        return outData;
    }

    /// <summary> Calculates LMemLoopbackCPU and LMemLoopbackDFE
    /// and checks if they return the same value. 
    /// </summary>
    /// <param name = "args"> Command line arguments </param>
    public static void Main(string[] args)
    {
        Stopwatch sw = new Stopwatch();
        int status;

        // Generate input data
        sw.Start();
        const int SIZE = 384;
        List<int> inA = new List<int>();
        List<int> inB = new List<int>();

        for (int i = 0; i < SIZE; i++)
        {
            inA.Add(i);
            inB.Add(SIZE - i);
        }

        sw.Stop();
        Console.WriteLine("Generating input data:\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

        // DFE Output
        sw.Reset();
        sw.Start();
        List<int> dataOutDFE = LMemLoopbackDFE(SIZE, inA, inB);
        sw.Stop();
        Console.WriteLine("LMemLoopback DFE total time:\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

        // CPU Output
        sw.Reset();
        sw.Start();
        List<int> dataOutCPU = LMemLoopbackCPU(SIZE, inA, inB);
        sw.Stop();
        Console.WriteLine("LMemLoopback CPU total time:\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

        // Checking results
        sw.Reset();
        sw.Start();
        status = Check(dataOutDFE, dataOutCPU, SIZE);
        sw.Stop();
        Console.WriteLine("Checking results:\t\t\t\t{0}s", sw.Elapsed.TotalMilliseconds / 1000);

        if (status > 0)
        {
            Console.WriteLine("Test failed {0} times! ", status);
            Environment.Exit(-1);
        } 
        else 
        {
            Console.WriteLine("Test passed!");
        }
    }
}
