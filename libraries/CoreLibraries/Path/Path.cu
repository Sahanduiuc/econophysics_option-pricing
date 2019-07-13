#include <cmath>	// sqrt, pow, fmax, log, exp, fabs

#include "Path.cuh"
#include "../../InputStructures/InputMarketData/Input_market_data.cuh"
#include "../../InputStructures/InputOptionData/Input_option_data.cuh"

using namespace std;

// Constructors
__device__ __host__ Path::Path(){
	this->_OptionType = NULL;
	this->_SpotPrice = 0.;
	this->_RiskFreeRate = NULL;
	this->_Volatility = NULL;
	this->_InitialPrice = NULL;
	this->_TimeToMaturity = NULL;
	this->_NumberOfIntervals = NULL;
	this->_DeltaTime = 0.;
	this->_StrikePrice = NULL;
	this->_B = NULL;
	this->_N = NULL;
	this->_K = NULL;
	this->_PerformanceCorridorBarrierCounter = 0;
	this->_NegativePrice = false;
}

__device__ __host__ Path::Path(const Input_market_data& market, const Input_option_data& option){
	this->_OptionType = &(option.OptionType);
	this->_SpotPrice = market.InitialPrice;
	this->_RiskFreeRate = &(market.RiskFreeRate);
	this->_Volatility = &(market.Volatility);
	this->_InitialPrice = &(market.InitialPrice);
	this->_TimeToMaturity = &(option.TimeToMaturity);
	this->_NumberOfIntervals = &(option.NumberOfIntervals);
	this->_DeltaTime = option.GetDeltaTime();
	this->_StrikePrice = &(option.StrikePrice);
	this->_B = &(option.B);
	this->_N = &(option.N);
	this->_K = &(option.K);
	this->_PerformanceCorridorBarrierCounter = 0;
	this->_NegativePrice = false;
}

// Public set methods
__device__ __host__ void Path::ResetToInitialState(const Input_market_data& market, const Input_option_data& option){
	this->_OptionType = &(option.OptionType);
	this->_SpotPrice = market.InitialPrice;
	this->_RiskFreeRate = &(market.RiskFreeRate);
	this->_Volatility = &(market.Volatility);
	this->_InitialPrice = &(market.InitialPrice);
	this->_TimeToMaturity = &(option.TimeToMaturity);
	this->_NumberOfIntervals = &(option.NumberOfIntervals);
	this->_DeltaTime = option.GetDeltaTime();
	this->_StrikePrice = &(option.StrikePrice);
	this->_B = &(option.B);
	this->_N = &(option.N);
	this->_K = &(option.K);
	this->_PerformanceCorridorBarrierCounter = 0;
	this->_NegativePrice = false;
}

__device__ __host__ void Path::ResetToInitialState(const Path& otherPath){
	this->_OptionType = otherPath._OptionType;
	this->_SpotPrice = otherPath._SpotPrice;
	this->_RiskFreeRate = otherPath._RiskFreeRate;
	this->_Volatility = otherPath._Volatility;
	this->_InitialPrice = otherPath._InitialPrice;
	this->_TimeToMaturity = otherPath._TimeToMaturity;
	this->_NumberOfIntervals = otherPath._NumberOfIntervals;
	this->_DeltaTime = otherPath._DeltaTime;
	this->_StrikePrice = otherPath._StrikePrice;
	this->_B = otherPath._B;
	this->_N = otherPath._N;
	this->_K = otherPath._K;
	this->_PerformanceCorridorBarrierCounter = otherPath._PerformanceCorridorBarrierCounter;
	this->_NegativePrice = otherPath._NegativePrice;
}

// Public get methods
__device__ __host__ double Path::GetSpotPrice() const{
	return this->_SpotPrice;
}

__device__ __host__ unsigned int Path::GetPerformanceCorridorBarrierCounter() const{
	return this->_PerformanceCorridorBarrierCounter;
}


// Euler and exact steps implementation
__device__ __host__ void Path::EulerLogNormalStep(double gaussianRandomVariable){
	double SpotPrice_i;		//The price at the next step
	SpotPrice_i = (this->_SpotPrice) *
	(1 + *(this->_RiskFreeRate) * this->_DeltaTime
	+ *(this->_Volatility) * sqrt(this->_DeltaTime) * gaussianRandomVariable);
	
	if(*(_OptionType) == 'e')
		this->CheckPerformanceCorridorCondition(this->_SpotPrice, SpotPrice_i);
		
	if(SpotPrice_i < 0)
		this->_NegativePrice = true;
	
	this->_SpotPrice = SpotPrice_i;
}

__device__ __host__ void Path::ExactLogNormalStep(double gaussianRandomVariable){
	double SpotPrice_i;		//The price at the next step
	SpotPrice_i = (this->_SpotPrice) * exp((*(this->_RiskFreeRate)
	- 0.5 * pow(*(this->_Volatility),2)) * this->_DeltaTime
	+ *(this->_Volatility) * gaussianRandomVariable * sqrt(this->_DeltaTime));
	
	if(*(_OptionType) == 'e')
		this->CheckPerformanceCorridorCondition(this->_SpotPrice, SpotPrice_i);
	
	this->_SpotPrice = SpotPrice_i;
}

// Check performance corridor condition
__device__ __host__ void Path::CheckPerformanceCorridorCondition(double currentSpotPrice, double nextSpotPrice){
	double modulusArgument = 1./(sqrt(this->_DeltaTime)) * log(nextSpotPrice / currentSpotPrice);
	double barrier = *(this->_B) * *(this->_Volatility);

	if(fabs(modulusArgument) < barrier)
		++(this->_PerformanceCorridorBarrierCounter);
}

// Evaluate atualized payoff
__device__ __host__ double Path::GetActualizedPayoff() const{
	double payoff;
	
	switch(*(this->_OptionType)){
		case 'f':
			payoff = this->_SpotPrice;
			break;
		
		case 'c':
			payoff = fmax(this->_SpotPrice - *(this->_StrikePrice), 0.);
			break;
		
		case 'p':
			payoff = fmax(*(this->_StrikePrice) - this->_SpotPrice, 0.);
			break;
		
		case 'e':
			payoff = *(this->_N) * fmax((static_cast<double>(this->_PerformanceCorridorBarrierCounter) / *(this->_NumberOfIntervals)) - *(this->_K), 0.);
			break;
			
		default:
			payoff = -10000.;
			break;
	}	
	
	return (payoff * exp(- *(this->_RiskFreeRate) * *(this->_TimeToMaturity)));
}

__device__ __host__ bool Path::GetNegativePrice() const{
	return this->_NegativePrice;
}

__device__ __host__ double Path::GetBlackAndScholesPrice() const{
	double d1 = 1./(*(this->_Volatility) * sqrt(*(this->_TimeToMaturity))) 
	* (log(*(this->_InitialPrice) / *(this->_StrikePrice))
	+ (*(this->_RiskFreeRate) + pow(*(this->_Volatility),2)/2) * *(this->_TimeToMaturity));

	double d2 = d1 -  *(this->_Volatility) * sqrt(*(this->_TimeToMaturity));

	if(*(this->_OptionType) == char('c')){
		double callPrice = *(this->_InitialPrice) * (0.5 * (1. + erf(d1/sqrt(2.)))) - *(this->_StrikePrice) 
		* exp(- *(this->_RiskFreeRate) * *(this->_TimeToMaturity))
		* (0.5 * (1. + erf(d2/sqrt(2.))));

		return callPrice;
	} 

	if(*(this->_OptionType) == char('p')){
		double putPrice = *(this->_InitialPrice) * ((0.5 * (1. + erf(d1/sqrt(2.)))) - 1) - *(this->_StrikePrice)
		* exp(- *(this->_RiskFreeRate) * *(this->_TimeToMaturity))
		* ((0.5 * (1. + erf(d2/sqrt(2.)))) - 1);

		return putPrice;
	}
}
