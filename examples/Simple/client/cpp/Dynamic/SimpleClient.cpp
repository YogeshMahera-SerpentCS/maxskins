/* Copyright 2016 Maxeler Technologies */
#include <thrift/protocol/TBinaryProtocol.h>
#include <thrift/transport/TSocket.h>
#include <thrift/transport/TTransportUtils.h>

#include <stdlib.h>

#include <vector>

#include "../gen-cpp/SimpleService.h"

using std::cout;
using std::endl;

using apache::thrift::TException;
using apache::thrift::protocol::TBinaryProtocol;
using apache::thrift::protocol::TProtocol;
using apache::thrift::transport::TBufferedTransport;
using apache::thrift::transport::TSocket;
using apache::thrift::transport::TTransport;

using ::com::maxeler::Simple::SimpleServiceClient;
using ::com::maxeler::Simple::remote_ptr;

/**
 * Calculates how much time pasted from strartTime.
 *
 * @param startTime  Starting time
 *
 * @return           Time difference in seconds
 */
double calcTime(struct timeval startTime) {
  struct timeval endTime;

  gettimeofday(&endTime, NULL);

  double seconds  = endTime.tv_sec  - startTime.tv_sec;
  double useconds = endTime.tv_usec - startTime.tv_usec;

  return (((seconds) * 1000 + useconds / 1000.0) + 0.5) / 1000;
}

/**
 * Checks if SimpleDFE and SimpleCPU return the same value.
 *
 * @param dataOutDfe  Data output from DFE
 * @param dataOutCpu  Data output from CPU
 * @param size        Size
 */
void check(std::vector<double> dataOutDFE,
           std::vector<double> dataOutCPU, int size) {
  for (int i = 0; i < size; i++) {
    if (dataOutDFE[i] != dataOutCPU[i]) {
      fprintf(stderr, "Output data @ %d = %d (expected %d)\n",
              i, dataOutDFE[i], dataOutCPU[i]);

      cout << "Test failed." << endl;
      exit(-1);
    }
  }

  cout << "Test passed!" << endl;
}

/**
 * Simple on CPU.
 *
 * @param size    Size
 * @param dataIn  Data input
 *
 * @return        Data output
 */
std::vector<double> SimpleCPU(int size, std::vector<double> dataIn) {
  std::vector<double> dataOut(size);

  for (int i = 0 ; i < size ; i++) {
    dataOut[i] = dataIn[i] * dataIn[i] + dataIn[i];
  }

  return dataOut;
}

/**
 * Simple on DFE.
 *
 * @param size    Size
 * @param dataIn  Data input
 *
 * @return        Data output
 */
std::vector<double> SimpleDFE(int size, std::vector<double> dataIn) {
  std::vector<double> dataOut(size);

  struct timeval startTime;

  gettimeofday(&startTime, NULL);

  // Make socket
  boost::shared_ptr<TTransport> socket(new TSocket("localhost", 9090));

  // Buffering is critical. Raw sockets are very slow
  boost::shared_ptr<TTransport> transport(new TBufferedTransport(socket));

  // Wrap in a protocol
  boost::shared_ptr<TProtocol> protocol(new TBinaryProtocol(transport));

  // Create a client to use the protocol encoder
  SimpleServiceClient client(protocol);

  cout << "Creating a client:\t\t\t\t";
  cout << calcTime(startTime) << "s" << endl;

  try {
    // Connect!
    gettimeofday(&startTime, NULL);
    transport->open();
    cout << "Opening connection:\t\t\t\t";
    cout << calcTime(startTime) << "s" << endl;

    // Initialize maxfile
    gettimeofday(&startTime, NULL);
    remote_ptr maxfile = client.Simple_init();
    cout << "Initializing maxfile:\t\t\t\t";
    cout << calcTime(startTime) << "s" << endl;

    // Load DFE
    gettimeofday(&startTime, NULL);
    remote_ptr engine = client.max_load(maxfile, "*");
    cout << "Loading DFE:\t\t\t\t\t";
    cout << calcTime(startTime) << "s" << endl;

    // Allocate and send input streams to server
    gettimeofday(&startTime, NULL);
    remote_ptr address_dataIn = client.malloc_float(size);
    client.send_data_float(address_dataIn, dataIn);
    cout << "Sending input data:\t\t\t\t";
    cout << calcTime(startTime) << "s" << endl;

    // Allocate memory for output stream on server
    gettimeofday(&startTime, NULL);
    remote_ptr address_dataOut = client.malloc_float(size);
    cout << "Allocating memory for output stream on server:\t";
    cout << calcTime(startTime) << "s" << endl;

    // Action default

    int sizeBytes = size * sizeof(float);

    remote_ptr actions = client.max_actions_init(maxfile, "default");
    client.max_set_param_uint64t(actions, "N", size);
    client.max_queue_input(actions, "x", address_dataIn, sizeBytes);
    client.max_queue_output(actions, "y", address_dataOut, sizeBytes);

    client.max_run(engine, actions);

    cout << "Pass through time:\t\t\t\t";
    cout << calcTime(startTime) << "s" << endl;

    // Unload DFE
    gettimeofday(&startTime, NULL);
    client.max_unload(engine);
    cout << "Unloading DFE:\t\t\t\t\t";
    cout << calcTime(startTime) << "s" << endl;

    // Get output stream from server
    gettimeofday(&startTime, NULL);
    client.receive_data_float(dataOut, address_dataOut, size);
    cout << "Getting output stream:\t(size = " << size * 32 << " bit)\t";
    cout << calcTime(startTime) << "s" << endl;

    // Free allocated memory for streams on server
    gettimeofday(&startTime, NULL);
    client.free(address_dataIn);
    client.free(address_dataOut);
    client.free(actions);
    cout << "Freeing allocated memory for streams on server:\t";
    cout << calcTime(startTime) << "s" << endl;

    // Free allocated maxfile data
    gettimeofday(&startTime, NULL);
    client.Simple_free();
    cout << "Freeing allocated maxfile data:\t\t\t";
    cout << calcTime(startTime) << "s" << endl;

    // Close!
    gettimeofday(&startTime, NULL);
    transport->close();
    cout << "Closing connection:\t\t\t\t";
    cout << calcTime(startTime) << "s" << endl;
  } catch (TException& tx) {
    cout << "ERROR: " << tx.what() << endl;
    exit(-1);
  }

  return dataOut;
}

/**
 * Calculates SimpleDFE and SimpleCPU and
 * checks if they return the same value.
 */
int main() {
  struct timeval startTime;

  // Input
  gettimeofday(&startTime, NULL);

  const int size = 1024;
  std::vector<double> dataIn;

  for (int i = 0; i < size; i++) {
    dataIn.push_back(i + 1);
  }

  cout << "Generating input data:\t\t\t\t";
  cout << calcTime(startTime) << "s" << endl;

  // DFE Output
  gettimeofday(&startTime, NULL);
  std::vector<double> dataOutDFE = SimpleDFE(size, dataIn);
  cout << "DFE pass through total time:\t\t\t";
  cout << calcTime(startTime) << "s" << endl;

  // CPU Output
  gettimeofday(&startTime, NULL);
  std::vector<double> dataOutCPU = SimpleCPU(size, dataIn);
  cout << "CPU pass through total time:\t\t\t";
  cout << calcTime(startTime) << "s" << endl;

  // Checking results
  check(dataOutDFE, dataOutCPU, size);

  return 0;
}

