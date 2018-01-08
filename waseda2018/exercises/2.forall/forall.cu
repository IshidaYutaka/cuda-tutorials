#include <stdio.h>
#include <cuda.h>

#define CUDA_ERROR_CHECK
#define CudaSafeCall( err ) __cudaSafeCall( err, __FILE__, __LINE__ )

inline void __cudaSafeCall( cudaError err, const char *file, const int line )
{
    #ifdef CUDA_ERROR_CHECK
    if ( cudaSuccess != err )
    {
	fprintf( stderr, "cudaSafeCall() failed at %s:%i : %s\n",
		 file, line, cudaGetErrorString( err ) );
	exit( -1 );
    }
    #endif

    return;
}

__global__ void forall(int *dA)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    dA[i] = 1;
}

int main()
{

    // Step 1: Allocate memory on the host (use malloc)

    // Step 2: Allocate memory on the device (use cudaMalloc)

    // Step 3: Copy the host data to the device (use cudaMemcpy) 

    // Step 4: Launch the kernel
    forall<<<1,1>>>();
    CudaSafeCall(cudaDeviceSynchronize());

    // Step 5: Copy back the data from the device (use cudaMemcpy)

    // Step 6: Verification

    // Step 7: Cleanup
    
    return 0;
}    
