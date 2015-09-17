#include <iostream>

#include <thrift/protocol/TBinaryProtocol.h>
#include <thrift/transport/TSocket.h>
#include <thrift/transport/TTransportUtils.h>
#include <stdlib.h>

#include "../gen-cpp/VectorAdditionService.h"

using namespace std;
using namespace apache::thrift;
using namespace apache::thrift::protocol;
using namespace apache::thrift::transport;

using namespace ::com::maxeler::VectorAddition;

void check(std::vector<int32_t> x, std::vector<int32_t> y, std::vector<int32_t> s, int scalar, int size)
{
	int status = 0;

	for(int i = 0; i < size; i++)
		if (s[i] != x[i] + y[i] + scalar) {
			cout << "Test failed!" << endl;
			status = 1;
			break;
		}

	if (!status) 
		cout << "Test successful!" << endl;
}

int main(int argc, char** argv) {

	boost::shared_ptr<TTransport> socket(new TSocket("localhost", 9090));
	boost::shared_ptr<TTransport> transport(new TBufferedTransport(socket));
	boost::shared_ptr<TProtocol> protocol(new TBinaryProtocol(transport));
	VectorAdditionServiceClient client(protocol);
	
	try {
	  
		transport->open();
  
		const int size = 384;
		int sizeBytes = size * sizeof(int32_t);
		std::vector<int32_t> x;
		std::vector<int32_t> y; 
		int scalar = 3;

		// Generate input data
		for(int i = 0; i<size; ++i) {
			x.push_back(random() % 100);
			y.push_back(random() % 100);
		}

		// Initialize maxfile
		remote_ptr maxfile = client.VectorAddition_init();

		// Load DFE
		remote_ptr engine = client.max_load(maxfile, "*");

		// Allocate and send input streams to server
		remote_ptr address_x = client.malloc_int32_t(size);
		client.send_data_int32_t(address_x, x);

		remote_ptr address_y = client.malloc_int32_t(size);
		client.send_data_int32_t(address_y, y);

		// Allocate memory for output stream on server
		remote_ptr address_s = client.malloc_int32_t(size);

		cout << "Writing to LMem." << endl;
	   
		VectorAddition_writeLMem_actions_t_struct actions_lmem;

		actions_lmem.__set_param_address(0);
		actions_lmem.__set_param_nbytes(sizeBytes);
		actions_lmem.__set_instream_cpu_to_lmem(address_x);

		remote_ptr address_actions_lmem = client.send_VectorAddition_writeLMem_actions_t(actions_lmem);

		client.VectorAddition_writeLMem_run(engine, address_actions_lmem); 

		cout << "Running on DFE." << endl;
		
		VectorAddition_actions_t_struct actions;

		actions.__set_param_A(scalar);
		actions.__set_param_N(size);
		actions.__set_instream_y(address_y);
		actions.__set_outstream_s(address_s);

		remote_ptr address_actions = client.send_VectorAddition_actions_t(actions);

		client.VectorAddition_run(engine, address_actions);

		// Unload DFE
		client.max_unload (engine);

		// Get output stream from server
		std::vector<int32_t> s;
		s.resize(size);
		client.receive_data_int32_t(s, address_s, size);

		// Free allocated memory for streams on server
		client.free(address_x);
		client.free(address_y);
		client.free(address_s);

		// Free allocated maxfile data
		client.VectorAddition_free();

		// Checking results
		check(x, y, s, scalar, size);
	
		transport->close();
	
	} catch (TException& tx) {
		cout << "ERROR: " << tx.what() << endl;
	}

	return 0;
}