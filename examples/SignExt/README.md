# Sign Extension Example

An example project, which will receive packets containing 3 signed integer values of variable lengths, convert them to a fixed size and pass them to the CPU. Since the values are signed, we must consider sign extension.

The structure of the incoming packet *data* field should be as follows:

* First byte
    * defines the size of the following content (see table below)
* Rest of data
    * contains the three values A, B and C (in that order)
    * where n = size of A + size of B + size of C
    * little endian

Allocation of bits in the first data byte:

Bits  | 7 - 6 | 5 - 3 | 2 - 0
:---- |:-----:|:-----:|:-----:
Usage | size of C | size of B | size of A

These values indicate the sizes in bytes. If any of these sizes are equal to 0, this indicates the maximum possible size for that variable. E.g. for the size of B, 0x0 would indicate a length of 8 bytes.

The values passed to the CPU should be as follows:

* A : 64 bit signed integer
* B : 64 bit signed integer
* C : 32 bit signed integer 

## Running this example

This DFE is compiled for ISCA card using MaxCompiler 2014.2.

### Starting the simulator

To run it using simulator, first simulated ISCA card needs to be (re)started:

```bash
maxcompilersim -c ISCA -e QSFP_TOP_10G_PORT1:172.16.50.10:255.255.255.0 -p QSFP_TOP_10G_PORT1:top1.pcap restart
```

These environment variables need to be exported so this example can be executed:

```bash
export MAXELEROSDIR=$MAXCOMPILERDIR/lib/maxeleros-sim
export LD_PRELOAD=$MAXELEROSDIR/lib/libmaxeleros.so:$LD_PRELOAD
export SLIC_CONF="$SLIC_CONF;use_simulation=sim"
```

### Create skin for Python

Create skin from **examples/SignExt** directory with:

```bash
maxskins --py SignExt.max
```

### Create skin for Java

Create skin from **examples/SignExt** directory with:

```bash
maxskins --java SignExt.max
```

### Create skin for C++ 

Create skin from **examples/SignExt** directory with:

```bash
maxskins --cpp SignExt.max
```

### Create skin for C# 

Create skin from **examples/SignExt** directory with:

```bash
maxskins --csharp SignExt.max
```

### Create skin for Go 

Create skin from **examples/SignExt** directory with:

```bash
maxskins --go SignExt.max
```
    
### Create skin for Perl 

Create skin from **examples/SignExt** directory with:

```bash
maxskins --perl SignExt.max
```

### Create skin for Ruby 

Create skin from **examples/SignExt** directory with:

```bash
maxskins --rb SignExt.max
```

### Create skin for Erlang 

Create skin from **examples/SignExt** directory with:

```bash
maxskins --erl SignExt.max
```

### Create skin for Haskell 

Create skin from **examples/SignExt** directory with:

```bash
maxskins --hs SignExt.max
```
    
**Note:** maxskins command creates **client**, **server** and **.scratch** directories in the current directory. 
In the **client** directory there are Apache Thrift files necessary for client. 
In the **server** directory there is a binary file which is used to start the server. 
In the **.scratch** directory there are all files that are generated during the compiling process. 

### Start the server

Start the server from the created server directory (**examples/SignExt/server**) with:

```bash
./SignExt_server 9090 &
```

# Building

### Packet sender

Build the auxiliary application, used to send the packets located at (**examples/SignExt/sender**).

```bash
./build.py
```

### Run the Python example

Run the example from the **examples/SignExt/client/py/Dynamic/** directory with:

```bash
./signext.py 172.16.50.1 172.16.50.10
```

### Run the Java example

Run the example from the **examples/SignExt/client/java/Dynamic/** directory with:

```bash
ant -Darg1=172.16.50.1 -Darg2=172.16.50.10
```

### Run the C++ example

Run the example from the **examples/SignExt/client/cpp/Dynamic/** directory with:

```bash
make
./SignExt_client 172.16.50.1 172.16.50.10
```

### Run the C# example

Run the example from the **examples/SignExt/client/csharp/Dynamic/** directory with:

```bash
mcs /out:SignExt.exe SignExt.cs /recurse:../gen-csharp/com/maxeler/SignExt/*.cs /r:$MONO_PATH/Thrift.dll
mono SignExt.exe 172.16.50.1 172.16.50.10
```

### Run the Go example

Run the example from the **examples/SignExt/client/go/Dynamic/** directory with:

```bash
go run SignExt.go 172.16.50.1 172.16.50.10
```

### Run the Perl example

Run the example from the **examples/SignExt/client/perl/Dynamic/** directory with:

```bash
perl SignExt.pl 172.16.50.1 172.16.50.10
```

### Run the Ruby example

Run the example from the **examples/SignExt/client/rb/Dynamic/** directory with:

```bash
ruby SignExt.rb 172.16.50.1 172.16.50.10
```

### Run the Erlang example

Run the example from the **examples/SignExt/client/erl/Dynamic/** directory with:

```bash
erlc -I $EINCLUDEPATH -I $EBINPATH -I ../gen-erl/ -o ../gen-erl/ ../gen-erl/*.erl
erlc -I $EINCLUDEPATH -I ../gen-erl/ signExt.erl
erl -pa $EBINPATH -pa ../gen-erl/ -noshell -run signExt t 172.16.50.1 172.16.50.10 -s init stop
```

### Run the Haskell example

Run the example from the **examples/SignExt/client/hs/Dynamic/** directory with:

```bash
ghc -i$HASKELLPATH -o SignExt SignExt.hs
./SignExt 172.16.50.1 172.16.50.10
```

Then open a new terminal and inject some packets:

```bash
$ ./sender/sender
Sender finished
```

In the first terminal, you should see the received packet details:

```bash
Kernel got: aSz = 3, bSz = 0, cSz = 1
Kernel got: aSz = 6, bSz = 1, cSz = 3
CPU: Got output frame 1 - size 20 bytes
Frame [1] Word[0]: 0xffffffffff800201
Frame [1] Word[1]: 0x7766554433221100
Frame [1] Word[2]: 0xffffff80
CPU: Got output frame 2 - size 20 bytes
Frame [2] Word[0]: 0xffff800102030405
Frame [2] Word[1]: 0x78
Frame [2] Word[2]: 0xff818283
```

The application will continue to wait for more packets, so when you are finished, inject packets with:

```bash
$ ./sender/sender end
Sender finished
```
    
**Note:** Examples can not be run if the server is not started. 

### Stopping the simulator

After executing application, simulator can be stopped with the following command::

```bash
maxcompilersim -c ISCA stop
```

