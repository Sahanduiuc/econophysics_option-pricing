#include <iostream>
#include <cstdlib>
#include <fstream>		// ifstream
#include <ctime>		// time(NULL)
#include <random>		// C++11 Mersenne twister
#include <climits>		// UINT_MAX
#include <cmath>		// log, cos, sin, ceil, M_PI
#include <algorithm>	// min
#include <cstdio>

#include "libraries/InputStructures/InputGPUData/Input_gpu_data.cuh"
#include "libraries/InputStructures/InputMarketData/Input_market_data.cuh"
#include "libraries/InputStructures/InputMCData/Input_MC_data.cuh"
#include "libraries/InputStructures/InputOptionData/Input_option_data.cuh"
#include "libraries/CoreLibraries/DataStreamManager/Data_stream_manager.cuh"
#include "libraries/CoreLibraries/Statistics/Statistics.cuh"
#include "libraries/CoreLibraries/Path/Path.cuh"
#include "libraries/CoreLibraries/RandomGenerator/rng.cuh"
#include "libraries/CoreLibraries/SupportFunctions/Support_functions.cuh"
#include "libraries/OutputStructures/OutputMCData/Output_MC_data.cuh"

using namespace std;

int main(){
	
	// Read & print input data from file
	Data_stream_manager streamManager("input.dat");
	
	Input_gpu_data inputGPU;
	Input_market_data inputMarket;
	Input_option_data inputOption;
	Input_MC_data inputMC;
	streamManager.ReadInputData(inputGPU, inputOption, inputMarket, inputMC);
	
	unsigned int numberOfThreadsPerBlock = inputGPU.GetNumberOfThreadsPerBlock();
	unsigned int totalNumberOfThreads = inputGPU.GetTotalNumberOfThreads();
	unsigned int numberOfSimulationsPerThread = inputMC.GetNumberOfSimulationsPerThread(inputGPU);
	
	streamManager.PrintInputData(inputGPU, inputOption, inputMarket, inputMC);
															
	// Output arrays
	Statistics *exactOutputs = new Statistics[totalNumberOfThreads];
	Statistics *eulerOutputs = new Statistics[totalNumberOfThreads];

/*
	////////////// HOST-SIDE GENERATOR //////////////	
	cout << "Beginning device simulation through CPU..." << endl;
	// Simulating device function
	OptionPricingEvaluator_Host(inputGPU, inputOption, inputMarket, inputMC, exactOutputs, eulerOutputs);
	cout << endl;
	/////////////////////////////////////////////////
*/

///*
	////////////// DEVICE-SIDE GENERATOR //////////////
	Statistics *device_exactOutputs;
	Statistics *device_eulerOutputs;
	
	cudaMalloc((void **)&device_exactOutputs, totalNumberOfThreads*sizeof(Statistics));
	cudaMalloc((void **)&device_eulerOutputs, totalNumberOfThreads*sizeof(Statistics));
	
	cudaMemcpy(device_exactOutputs, exactOutputs, totalNumberOfThreads*sizeof(Statistics), cudaMemcpyHostToDevice);
	cudaMemcpy(device_eulerOutputs, eulerOutputs, totalNumberOfThreads*sizeof(Statistics), cudaMemcpyHostToDevice);

	cout << "Beginning GPU computation..." << endl;
	OptionPricingEvaluator_Global<<<inputGPU.NumberOfBlocks,numberOfThreadsPerBlock>>>(inputGPU, inputOption, inputMarket, inputMC, device_exactOutputs, device_eulerOutputs);

	cudaMemcpy(exactOutputs, device_exactOutputs, totalNumberOfThreads*sizeof(Statistics), cudaMemcpyDeviceToHost);
	cudaMemcpy(eulerOutputs, device_eulerOutputs, totalNumberOfThreads*sizeof(Statistics), cudaMemcpyDeviceToHost);

	cudaFree(device_exactOutputs);
	cudaFree(device_eulerOutputs);
	///////////////////////////////////////////////////
//*/
	
	// Compute results
	Statistics exactResults;
	Statistics eulerResults;
	
	for(unsigned int threadNumber=0; threadNumber<totalNumberOfThreads; ++threadNumber){
		exactResults += exactOutputs[threadNumber];
		eulerResults += eulerOutputs[threadNumber];
	}
	
	exactResults.EvaluateEstimatedPriceAndError();
	eulerResults.EvaluateEstimatedPriceAndError();
	
	// Elapsed time is temporary, will be implemented later
	double elapsedTime = 0.;
	
	// Global output MC
	Output_MC_data outputMC;
	streamManager.StoreOutputData(outputMC, exactResults, eulerResults, elapsedTime);
	streamManager.PrintOutputData(outputMC);
	
	// Trash bin section, where segfaults come to die
	delete[] exactOutputs;
	delete[] eulerOutputs;

	return 0;
}
