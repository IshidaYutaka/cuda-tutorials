#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <cuda.h>
#include "cub/cub/cub.cuh"

long long getCurrentTime()
{
    struct timeval te;
    gettimeofday(&te, NULL); // get current time
    long long  microseconds = te.tv_sec*1000000LL + te.tv_usec;
    return microseconds;
}

#define CUDA_ERROR_CHECK
#define CudaSafeCall( err ) __cudaSafeCall( err, __FILE__, __LINE__ )

inline void __cudaSafeCall( cudaError err, const char *file, const int line )
{
#ifdef CUDA_ERROR_CHECK
    if ( cudaSuccess != err ) {
        fprintf( stderr, "cudaSafeCall() failed at %s:%i : %s\n",
                 file, line, cudaGetErrorString( err ) );
        exit( -1 );
    }
#endif
    return;
}

int ReduceCPU(int *A, int N, double *cpuTime)
{
    long long startTime = getCurrentTime();
    int sum = 0;
    for (int i = 0; i < N; i++) {
        sum += A[i];
    }
    *cpuTime = (double)(getCurrentTime() - startTime) / 1000000;
    return sum;
}

int ReduceGPU(int *A, int N, double *gpuOverallTime, double *gpuKernelTime) {
    long long startTime = getCurrentTime();

    int threads = 512;
    int blocks = min((N + threads - 1) / threads, 1024);

    int *S = (int*)malloc(sizeof(int) * 1);
    int *dA;
    int *dSum;

    // Allocate memory on the device
    CudaSafeCall(cudaMalloc(&dA, sizeof(int) * N));
    CudaSafeCall(cudaMalloc(&dSum, sizeof(int) * 1));

    // Copy the data from the host to the device
    CudaSafeCall(cudaMemcpy(dA, A, N * sizeof (int), cudaMemcpyHostToDevice));
    CudaSafeCall(cudaMemset(dSum, 0, sizeof (int)));

    // Determine temporary device storage requirements
    size_t temp_storage_bytes = 0;
    int* temp_storage=NULL;
    int init = 0;
    cub::DeviceReduce::Reduce(temp_storage, temp_storage_bytes, dA, dSum, N, cub::Sum(), init);

    // Allocate temporary storage
    CudaSafeCall(cudaMalloc(&temp_storage, temp_storage_bytes));
    CudaSafeCall(cudaDeviceSynchronize());

    cudaEvent_t start, stop;
    CudaSafeCall(cudaEventCreate(&start));
    CudaSafeCall(cudaEventCreate(&stop));
    CudaSafeCall(cudaEventRecord(start));

    // Invoke the reduction library
    cub::DeviceReduce::Reduce(temp_storage, temp_storage_bytes, dA, dSum, N, cub::Sum(), init);
    CudaSafeCall(cudaEventRecord(stop));
    CudaSafeCall(cudaEventSynchronize(stop));
    CudaSafeCall(cudaDeviceSynchronize());

    // Copy back the data from the host
    CudaSafeCall(cudaMemcpy(S, dSum, 1 * sizeof (int), cudaMemcpyDeviceToHost));

    // Compute the performance numbers
    *gpuOverallTime = (double)(getCurrentTime() - startTime) / 1000000;
    float msec = 0;
    CudaSafeCall(cudaEventElapsedTime(&msec, start, stop));
    *gpuKernelTime = msec / 1000;

    // Clenaup
    CudaSafeCall(cudaFree(dA));
    CudaSafeCall(cudaFree(dSum));

    return *S;
}

int main(int argc, char **argv)
{

    if (argc != 2) {
        printf("Usage: ./reduce repeat\n");
        exit(0);
    }
    int REPEATS = atoi(argv[1]);

    for (int repeat = 0; repeat < REPEATS; repeat++) {
        printf("[Iteration %d]\n", repeat);
        for (int N = 1024; N < 256 * 1024 * 1024; N = N * 2) {
            int* A = NULL;
            double cpuTime = 0.0;
            double gpuOverallTime = 0.0;
            double gpuKernelTime = 0.0;

            A = (int*)malloc(sizeof(int) * N);

            for (int i = 0; i < N; i++) {
                A[i] = i;
            }

            // CPU version
            int expected = ReduceCPU(A, N, &cpuTime);

            // GPU version
            int computed = ReduceGPU(A, N, &gpuOverallTime, &gpuKernelTime);

            if (computed == expected) {
                float GB = (float)(N * 4) / (1024 * 1024 * 1024);
                printf ("\tVERIFIED, %d, CPU (%lf sec) %lf GB/s, GPU (Overall: %lf sec) %lf GB/s, GPU (Kernel: %lf sec) %lf GB/s\n", 4*N, cpuTime, GB / cpuTime, gpuOverallTime, GB / gpuOverallTime, gpuKernelTime, GB / gpuKernelTime);
            } else {
                printf ("\tFAILED, %d, computed: %d, excepted %u\n", 4*N, computed, expected);
            }

            free(A);

        }
    }
}
