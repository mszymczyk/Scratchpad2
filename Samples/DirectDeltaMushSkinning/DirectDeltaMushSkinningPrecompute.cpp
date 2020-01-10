#include "DirectDeltaMushSkinning_pch.h"
#include "DirectDeltaMushSkinningPrecompute.h"

#include "..\..\..\3rdParty\eigen-3.3.7\Eigen\Sparse"
#include "..\..\..\3rdParty\libigl\include\igl\cotmatrix.h"

//#include <Eigen/Dense>
//#include <Eigen/SVD>
//#include <Eigen/Sparse>

typedef double DDM_NUMTYPE;

typedef Eigen::SparseMatrix<DDM_NUMTYPE> EigenSparse;
typedef Eigen::Matrix<DDM_NUMTYPE, 4, 4> EigenMat4;
typedef Eigen::Matrix<DDM_NUMTYPE, 4, 1> EigenVec4;
typedef Eigen::Matrix<DDM_NUMTYPE, 3, 3> EigenMat3;
typedef Eigen::Matrix<DDM_NUMTYPE, 3, 1> EigenVec3;
typedef Eigen::Matrix<DDM_NUMTYPE, -1, -1> EigenMatX;

namespace spad
{

Matrix4 EigenMat4ToMatrix4( const EigenMat4 &e )
{
	Matrix4 m;

	for ( uint iRow = 0; iRow < 4; ++iRow )
	{
		for ( uint iCol = 0; iCol < 4; ++iCol )
		{
			m.setElem( iCol, iRow, static_cast<float>( e.coeff( iRow, iCol ) ) );
		}
	}

	return m;
}

float4x4 EigenMat4ToFloat4x4( const EigenMat4 &e )
{
	float4x4 m;
	float *mdata = reinterpret_cast<float*>( &m );
	const DDM_NUMTYPE *edata = e.data();

	for ( uint i = 0; i < 16; ++i )
	{
		mdata[i] = static_cast<float>( edata[i] );
	}

	return m;
}

float3x3 EigenMat3ToFloat3x3( const EigenMat3 &e )
{
	float3x3 m;
	float *mdata = reinterpret_cast<float*>( &m );
	const DDM_NUMTYPE *edata = e.data();

	for ( uint i = 0; i < 9; ++i )
	{
		mdata[i] = static_cast<float>( edata[i] );
	}

	return m;
}

float3 EigenVec3ToFloat3( const EigenVec3 &e )
{
	float3 m;

	const DDM_NUMTYPE *edata = e.data();

	for ( uint i = 0; i < 3; ++i )
	{
		m[i] = static_cast<float>( edata[i] );
	}

	return m;
}

EigenMat4 Matrix4ToEigenMat4( const Matrix4 &m )
{
	EigenMat4 e;

	for ( uint iRow = 0; iRow < 4; ++iRow )
	{
		for ( uint iCol = 0; iCol < 4; ++iCol )
		{
			e.coeffRef( iRow, iCol ) = m.getElem( iCol, iRow ).getAsFloat();
		}
	}

	return e;
}

static EigenMat4 psi( const EigenSparse &B, const Eigen::MatrixX3d &U, const EigenSparse &W, uint numVerts, const uint i, const uint j )
{
	EigenMat4 sum = EigenMat4::Zero();

	// Sum psi, a sum over all verts for a given weight.

	for ( uint k = 0; k < numVerts; k++ )
	{
		double w = W.coeff( k, j );
		double b = B.coeff( k, i );
		if ( w != 0 && b != 0 )
		{
			EigenVec3 r = U.row( k );
			EigenVec4 rw( r[0], r[1], r[2], 1 );
			EigenMat4 hh = ( rw * rw.transpose() );
			EigenMat4 h = b * w * hh;
			sum += h;
			//if ( h != h.transpose() )
			//{
			//	h = h.transpose();
			//}
		}
	}
	return sum;
};


static EigenVec3 p_i( const EigenSparse &B, const Eigen::MatrixX3d &U, const EigenSparse &W, uint numVerts, uint numTransforms, const int ii )
{
	EigenMat4 sum = EigenMat4::Zero();
	for ( uint j = 0; j < numTransforms; j++ )
	{
		sum += psi( B, U, W, numVerts, ii, j );
	}
	//if ( sum != sum.transpose() )
	//{
	//	//throw sum;
	//	SPAD_ASSERTMSG( "wtf" );
	//}
	return sum.block( 0, 3, 3, 1 ).eval();
};


static DDM_NUMTYPE w_prime( const EigenSparse &C, const EigenSparse &W, uint numVerts, const uint i, const uint j )
{
	double sum = 0;
	for ( uint k = 0; k < numVerts; k++ )
	{
		double w = W.coeff( k, j );
		double c = C.coeff( k, i );
		sum += w * c;
	}
	return sum;
};


static EigenMat4 omega( const EigenSparse &B, const EigenSparse &C, const Eigen::MatrixX3d &U, const EigenSparse &W, uint numVerts, uint numTransforms, float dmBlend, const uint i, const uint j )
{
	EigenVec3 p_ii = p_i( B, U, W, numVerts, numTransforms, i );
	EigenMat4 pimat;
	pimat << ( p_ii * p_ii.transpose() ), p_ii, p_ii.transpose(), 1;
	EigenMat4 psi_ij = psi( B, U, W, numVerts, i, j );
	return ( ( 1.0 - dmBlend ) * (psi_ij)+( dmBlend * w_prime( C, W, numVerts, i, j ) ) * pimat ).eval();

	//EigenMat4 psi_ij = psi( B, U, W, numVerts, i, j );
	//return psi_ij;
};


//void PrecomputeDDM( DDMMesh &mesh )
void PrecomputeDDM(
	  const std::vector<BaseVertexPrecompute> &vertices
	, const std::vector<uint> &indices
	, const uint numTransforms
	, OmegaRefVector &outOmegaRefs
	, Matrix4Vector &outOmegas
	, std::vector<uint> &outTransformIndices
)
{
	CpuTimeQuery timer;
	BeginCpuTimeQuery( timer );

	const uint numVerts = truncate_cast<uint>( vertices.size() );
	const uint numTris = truncate_cast<uint>( indices.size() / 3 );
	//const uint numTransforms = truncate_cast<uint>( mesh.bones.size() );

	Eigen::MatrixX3d U; // n by 3 matrix of undeformed vertex positions
	U.resize( numVerts, Eigen::NoChange );
	for ( uint iVert = 0; iVert < numVerts; ++iVert )
	{
		const BaseVertexPrecompute &src = vertices[iVert];
		U.row( iVert ) = Eigen::RowVector3d( src.x, src.y, src.z );
	}

	Eigen::MatrixX3i F; // n by 3 matrix of undeformed triangle indices
	F.resize( numTris, Eigen::NoChange );
	for ( uint iTri = 0; iTri < numTris; ++iTri )
	{
		const uint tri0 = indices[iTri * 3 + 0];
		const uint tri1 = indices[iTri * 3 + 1];
		const uint tri2 = indices[iTri * 3 + 2];
		F.row( iTri ) = Eigen::RowVector3i( tri0, tri1, tri2 );
	}


	// Weights & other maps
	EigenSparse W( numVerts, numTransforms );
	W.reserve( 4 ); // Assuming approximately 4 weights per vertex

	for ( uint iVert = 0; iVert < numVerts; ++iVert )
	{
		const BaseVertexPrecompute &src = vertices[iVert];
		for ( uint iWeight = 0; iWeight < src.numWeights; ++iWeight )
		{
			W.insert( iVert, src.b[iWeight] ) = src.w[iWeight];
		}
	}

	//Laplacian matrix
	EigenSparse lapl;
	igl::cotmatrix( U, F, lapl ); // Compute standard laplacian matrix
	EigenMatX lapl_diag_inv = lapl.diagonal().asDiagonal().inverse(); //Normalize
	EigenSparse L = ( lapl * lapl_diag_inv ).sparseView().eval(); // Normalized!

	// Vars needed for solver. Solver is used to calculate sparse inverses.
	EigenSparse I( numVerts, numVerts );
	I.setIdentity();

	Eigen::SparseLU<EigenSparse> solver_b;
	Eigen::SparseLU<EigenSparse> solver_c;

	//const float transSmooth = 10.1f;
	//const float rotSmooth = 10.1f;
	//const uint steps = 20;
	const float transSmooth = 1.0f;
	const float rotSmooth = 1.0f;
	const uint steps = 2;
	const float dmBlend = 0.0f;

	// Implicitly solve.
	// This is a slight deviation from the original paper, which has parameters for
	// steps and the separate translation and rotation smoothing. For an artist, it's
	// easier to think in terms of the total desired amount of smoothing and the
	// number of steps as a precision parameter, rather than having to tune them in
	// tandem for each change.
	//EigenSparse b( I + /*( transSmooth / (double)steps ) **/ L /*transSmoothMap.asDiagonal()*/ );
	//EigenSparse c( I + /*( rotSmooth / (double)steps ) **/ L /*rotSmoothMap.asDiagonal()*/ );
	EigenSparse b( I + transSmooth * L /*transSmoothMap.asDiagonal()*/ );
	EigenSparse c( I + rotSmooth * L /*rotSmoothMap.asDiagonal()*/ );

	EigenSparse B( I );
	EigenSparse B_next;
	solver_b.compute( b.transpose() );
	for ( int i = 0; i < steps; i++ )
	{
		B.makeCompressed();
		// This is the slow part
		B_next = solver_b.solve( B );
		B = B_next;
	}

	EigenSparse C( I );
	EigenSparse C_next;
	solver_c.compute( c.transpose() );
	for ( int i = 0; i < steps; i++ ) {
		C.makeCompressed();
		C_next = solver_c.solve( C );
		C = C_next;
	}

	//typedef std::vector<Matrix4, stdutil::aligned_allocator<Matrix4, alignof( Matrix4 )>> Matrix4Vector;
	////typedef std::vector<Matrix4Vector, stdutil::aligned_allocator<Matrix4Vector, alignof( Matrix4Vector )>> Matrix4Matrix;

	//struct OmegaRef
	//{
	//	uint firstIndex;
	//	uint indexCount;
	//};

	//typedef std::vector<OmegaRef> OmegaRefVector;

	// Actually precompute omegas.
	//Matrix4Matrix omegas;
	//Matrix4Vector omegas;
	//std::vector<uint> transformIndices;
	//omegas.reserve( numVerts * numTransforms / 2 );
	//OmegaRefVector omegaRefs;
	outOmegaRefs.clear();
	outOmegas.clear();
	outTransformIndices.clear();

	outOmegaRefs.resize( numVerts );

	for ( uint ii = 0; ii < numVerts; ii++ )
	{
		//omegas.push_back( std::list<std::pair<int, Mat4>>() );
		//auto& e = omegas.at( ii );
		//e.clear();

		//Matrix4Vector &vec = omegas[ii];
		//vec.resize( numTransforms );

		OmegaRef oref = {};
		bool orefValid = false;

		for ( uint jj = 0; jj < numTransforms; jj++ )
		{
			// This could be optimized more by not storing zero matrices
			//if(W.coeff(ii,jj) != 0)
			//{
			EigenMat4 o = omega( B, C, U, W, numVerts, numTransforms, dmBlend, ii, jj );
			//vec[jj] = EigenMat4ToMatrix4( o );
			Matrix4 m = EigenMat4ToMatrix4( o );
			//e.push_back( std::pair<int, Mat4>( jj, o ) );
			//}
			const float *f = reinterpret_cast<const float*>( &m );
			uint iElem = 0;
			for ( ; iElem < 16; ++iElem )
			{
				if ( fabsf( f[iElem] ) > FLT_EPSILON )
				{
					break;
				}
			}

			if ( iElem < 16 )
			{
				if ( !orefValid )
				{
					orefValid = true;
					oref.firstIndex = truncate_cast<uint>( outOmegas.size() );
				}

				outOmegas.push_back( m );
				outTransformIndices.push_back( jj );

				oref.indexCount += 1;
			}
		}

		outOmegaRefs[ii] = oref;
	}

	const size_t nOmegaMatrices = numVerts * numTransforms;
	const size_t memUsed = nOmegaMatrices * sizeof( Matrix4 );
	const size_t memUsedkB = memUsed / 1024;

	//// Compact
	//Matrix4 zeroMatrix;
	//memset( &zeroMatrix, 0, sizeof( zeroMatrix ) );
	//size_t nOmegaMatricesCompacted = 0;

	//Matrix4Matrix omegasCompacted;
	//for ( uint ii = 0; ii < numVerts; ii++ )
	//{
	//	Matrix4Vector &vec = omegas[ii];

	//	for ( uint jj = 0; jj < numTransforms; jj++ )
	//	{
	//		Matrix4 m = omegas[ii][jj];
	//		if ( memcmp( &m, &zeroMatrix, sizeof( Matrix4 ) ) )
	//		{
	//			vec.push_back( m );
	//			nOmegaMatricesCompacted += 1;
	//		}
	//	}
	//}

	EndCpuTimeQuery( timer );

	logInfo( "Precompute duration %u [ms]", timer.durationUS_ / 1000 );
}

#pragma optimize( "", off )

void DDMSkinCPU(
	  const std::vector<BaseVertex> &vertices
	, const Matrix4Vector &transforms
	, const OmegaRefVector &omegaRefs
	, const Matrix4Vector &omegas
	, const std::vector<uint> &transformIndices
	, std::vector<SkinnedVertex> &outSkinnedVertices
	, std::vector<DebugOutput> &outDebug
)
{
	for ( size_t vertIndex = 0; vertIndex < vertices.size(); ++vertIndex )
	{
		const BaseVertex &bv = vertices[vertIndex];
		const OmegaRef &oref = omegaRefs[vertIndex];

		EigenMat4 qmat;
		qmat.setZero();

		for ( uint iRef = 0; iRef < oref.indexCount; ++iRef )
		{
			uint j = iRef + oref.firstIndex;
			uint boneIndex = transformIndices[j];
			Matrix4 skinMat = transforms[boneIndex];
			Matrix4 omega_ij = omegas[j];

			EigenMat4 eskinMat = Matrix4ToEigenMat4( transpose( skinMat ) );
			EigenMat4 eomega_ij = Matrix4ToEigenMat4( omega_ij );

			EigenMat4 tmp = eomega_ij * eskinMat;
			//EigenMat4 tmp = eskinMat * eomega_ij;

			qmat += tmp;
		}

		qmat.transposeInPlace();

		const DDM_NUMTYPE *qmatData = qmat.data();

		EigenMat3 Qi = qmat.block( 0, 0, 3, 3 );
		EigenVec3 qi = qmat.block( 0, 3, 3, 1 );
		EigenVec3 pi = qmat.block( 3, 0, 1, 3 ).transpose();

		const DDM_NUMTYPE *QiData = Qi.data();
		const DDM_NUMTYPE *qiData = qi.data();
		const DDM_NUMTYPE *piData = pi.data();

		// Rotation
		EigenMat3 M = Qi - ( qi * pi.transpose() );
		const DDM_NUMTYPE *MData = M.data();

		Eigen::JacobiSVD<EigenMat3> svd;
		svd.compute( M, Eigen::ComputeFullU | Eigen::ComputeFullV );
		EigenMat3 U = svd.matrixU();
		EigenMat3 V = svd.matrixV().transpose();
		EigenMat3 R = ( U * V );

		outDebug[vertIndex].qmat = EigenMat4ToFloat4x4( qmat );
		outDebug[vertIndex].Q_i = EigenMat3ToFloat3x3( Qi );
		outDebug[vertIndex].q_i = EigenVec3ToFloat3( qi );
		outDebug[vertIndex].p_i_T = EigenVec3ToFloat3( pi );
		outDebug[vertIndex].m = EigenMat3ToFloat3x3( M );
		outDebug[vertIndex].svdU = EigenMat3ToFloat3x3( U );
		outDebug[vertIndex].svdV = EigenMat3ToFloat3x3( V );
		float3x3 S;
		memset( &S, 0, sizeof( S ) );
		S[0][0] = static_cast<float>( svd.singularValues()[0] );
		S[1][1] = static_cast<float>( svd.singularValues()[1] );
		S[2][2] = static_cast<float>( svd.singularValues()[2] );
		outDebug[vertIndex].svdS = S;

		const DDM_NUMTYPE *UData = U.data();
		const DDM_NUMTYPE *VData = V.data();

		//Translation
		EigenVec3 ti = qi - ( R * pi );

		EigenMat4 gamma;
		gamma << R, ti, 0, 0, 0, 1;

		EigenVec4 pt_h( bv.x, bv.y, bv.z, 1 );

		EigenVec4 final_pt = gamma * pt_h;

		//pt = MPoint( final_pt[0], final_pt[1], final_pt[2] );

		SkinnedVertex &sv = outSkinnedVertices[vertIndex];
		sv.x = static_cast<float>( final_pt[0] );
		sv.y = static_cast<float>( final_pt[1] );
		sv.z = static_cast<float>( final_pt[2] );
		sv.nx = 1;
		sv.ny = 0;
		sv.nz = 0;
	}


}

}
