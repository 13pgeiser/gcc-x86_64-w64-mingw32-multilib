#include <iostream>
#include <string>
#include <thread>

using namespace std;

void thread_function(string msg)
{
    cout << "Hello from: " << msg << endl;
}

int main(int argc, char* argv[]) {
	thread t(thread_function, "Thread 1");
	t.join();
	return 0;
}
