## Lua rOS Simulation

Very simple emulation of the ROS master-publisher-subscriber paradigm. It uses pure Lua and based on coroutines. 

Similarities:
* separated nodes communicate with each other via master 
* nodes can send and receive messages 
* node structure is similar to the original ROS implementation
Differences:
* no network communication
* only publishers and subscribers, no services and other features
* not for blocking calls
* messages are simple Lua tables (arrays) with strings or numbers

To see the example, execute 

    ./lossrun.lua publisher.lua subscriber.lua 

