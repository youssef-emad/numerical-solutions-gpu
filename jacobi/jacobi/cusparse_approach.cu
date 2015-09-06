#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <cusparse.h>

__global__ void divide(float *x, float* y ,float* out ,const int size)
{
    const int index = threadIdx.x;

	if (index < size)
	{
		out[index] = x[index]/y[index] ;	
	}
}

void jacobi_cusparse()
{
	//initialize our test cases
    const int m = 4;
	const int nnz = 4 ;
	const float alpha = -1.0;
    const float beta = 1.0;
	float values[] = {0,0,0,0} ;
	float diagonal_values[] = {0.1667,0.1667,0.1667,0.1667} ;
	int rowPtr[] = {0,1,2,3,4,7};
	int colIdx[] = {0,1,2,3};

	float y[] = {0.2036,0.2036,0.2036,0.2036};
	float x[] = {0,0,0,0};

	float *dev_values = 0 ;
	float *dev_diagonal_values = 0 ;
	int *dev_rowPtr = 0 ;
	int *dev_colIdx = 0 ;
	float *dev_x = 0 ;
	float *dev_y = 0 ;
 
	//Define the cusparse opaque structures
    cusparseHandle_t handle;
    cusparseStatus_t status = cusparseCreate(&handle);

	cusparseMatDescr_t descr = 0;
    cusparseCreateMatDescr(&descr);
    cusparseSetMatType(descr,CUSPARSE_MATRIX_TYPE_GENERAL);
    cusparseSetMatIndexBase(descr,CUSPARSE_INDEX_BASE_ZERO);

    // Choose which GPU to run on, change this on a multi-GPU system.
    cudaSetDevice(0);
    
	// Allocate GPU buffers for three vectors (two input, one output)    .
    cudaMalloc((void**)&dev_x, m * sizeof(float));
	cudaMalloc((void**)&dev_y, m * sizeof(float));
	cudaMalloc((void**)&dev_values, nnz * sizeof(float));
	cudaMalloc((void**)&dev_diagonal_values, nnz * sizeof(float));
	cudaMalloc((void**)&dev_rowPtr, (m+1) * sizeof(int));
	cudaMalloc((void**)&dev_colIdx, nnz * sizeof(int));
  
	//Memcpy
	cudaMemcpyAsync(dev_x, x, m * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpyAsync(dev_values, values, nnz * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpyAsync(dev_diagonal_values, diagonal_values, nnz * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpyAsync(dev_rowPtr, rowPtr, (m+1) * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpyAsync(dev_colIdx, colIdx, nnz * sizeof(int), cudaMemcpyHostToDevice);

	for (int i = 0 ; i<30 ; i++)
	{
		cudaMemcpyAsync(dev_y, y, m * sizeof(float), cudaMemcpyHostToDevice);

		cusparseScsrmv(handle, CUSPARSE_OPERATION_NON_TRANSPOSE,
                                            m, m, nnz, &alpha,
                                            descr, dev_values, dev_rowPtr,
                                            dev_colIdx, dev_x, &beta,dev_y);
		divide<<<1,m>>>(dev_y,dev_diagonal_values,dev_x,m);	
	}

	cudaMemcpyAsync(x, dev_x, m*sizeof(float), cudaMemcpyDeviceToHost );
	cudaMemcpyAsync(y, dev_y, m*sizeof(float), cudaMemcpyDeviceToHost );

	// cudaDeviceReset must be called before exiting in order for profiling and
    // tracing tools such as Nsight and Visual Profiler to show complete traces.
     cudaDeviceReset();
    
	system("pause");

    cudaFree(dev_x);
    cudaFree(dev_y);
    cudaFree(dev_values);
	cudaFree(dev_rowPtr);
	cudaFree(dev_colIdx);
}

