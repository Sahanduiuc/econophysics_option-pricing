#ifndef __Path_h__
#define __Path_h__

#include "../InputMarketData/Input_market_data.cuh"
#include "../InputOptionData/Input_option_data.cuh"

#include <iostream>

class Path{

	private:

		// Ricordarsi di mettere i puntatori
		
		double _SpotPrice;		// The step (spotprice) required to generate the next one

		// Market data
		double _RiskFreeRate;
		double _Volatility;

		// Base European option data
		char _OptionType[2];
		double _DeltaTime;
		
		// Performance corridor data
		double _B;
		double _N;
		double _K;
		unsigned int _PerformanceCorridorBarrierCounter;
		
		void CheckPerformanceCorridorCondition(double currentSpotPrice, double nextSpotPrice);
		
	public:

		__device__ __host__ Path() = default;
		__device__ __host__ Path(const Input_market_data& market, const Input_option_data& option, double SpotPrice);
		__device__ __host__ Path(const Input_market_data& market, const Input_option_data_PlainVanilla& option, double SpotPrice);
		__device__ __host__ Path(const Input_market_data& market, const Input_option_data_PerformanceCorridor& option, double SpotPrice);
		__device__ __host__ ~Path() = default;

		__device__ __host__ void SetInternalData(const Input_market_data& market, const Input_option_data& option, double SpotPrice);
		__device__ __host__ void SetInternalData(const Input_market_data& market, const Input_option_data_PlainVanilla& option, double SpotPrice);
		__device__ __host__ void SetInternalData(const Input_market_data& market, const Input_option_data_PerformanceCorridor& option, double SpotPrice);
		__device__ __host__ void SetInternalData(const Path&);

		__device__ __host__ void EulerLogNormalStep(double gaussianRandomVariable);
		__device__ __host__ void ExactLogNormalStep(double gaussianRandomVariable);
		
		__device__ __host__ double GetSpotPrice() const;
};
#endif
