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

static EigenMat4 psi( const EigenSparse &B, const Eigen::MatrixX3d &U, const EigenSparse &W, uint numVerts, const long i, const long j )
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
			EigenVec4 rw( U.coeff( k, 0 ), U.coeff( k, 1 ), U.coeff( k, 2 ), 1 );
			EigenMat4 hh = ( rw * rw.transpose() );
			EigenMat4 h = b * w * hh;
			sum += h;
			if ( h != h.transpose() )
			{
				h = h.transpose();
			}
		}
	}
	return sum;
};

void PrecomputeDDM( DDMMesh &mesh )
{
	const uint numVerts = truncate_cast<uint>( mesh.vertices.size() );
	const uint numTris = truncate_cast<uint>( mesh.indices.size() / 3 );
	const uint numTransforms = truncate_cast<uint>( mesh.bones.size() );

	Eigen::MatrixX3d U; // n by 3 matrix of undeformed vertex positions
	U.resize( numVerts, Eigen::NoChange );
	for ( uint iVert = 0; iVert < numVerts; ++iVert )
	{
		const BaseVertex &src = mesh.vertices[iVert];
		U.row( iVert ) = Eigen::RowVector3d( src.x, src.y, src.z );
	}

	Eigen::MatrixX3i F; // n by 3 matrix of undeformed triangle indices
	F.resize( numTris, Eigen::NoChange );
	for ( uint iTri = 0; iTri < numTris; ++iTri )
	{
		const uint tri0 = mesh.indices[iTri * 3 + 0];
		const uint tri1 = mesh.indices[iTri * 3 + 1];
		const uint tri2 = mesh.indices[iTri * 3 + 2];
		F.row( iTri ) = Eigen::RowVector3i( tri0, tri1, tri2 );
	}


	// Weights & other maps
	EigenSparse W( numVerts, numTransforms );
	W.reserve( 4 ); // Assuming approximately 4 weights per vertex

	for ( uint iVert = 0; iVert < numVerts; ++iVert )
	{
		const BaseVertex &src = mesh.vertices[iVert];
		for ( uint iWeight = 0; iWeight < src.numWeights; ++iWeight )
		{
			W.insert( iVert, iWeight ) = src.w[iWeight];
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

	const float transSmooth = 1.0f;
	const float rotSmooth = 1.0f;
	const uint steps = 2;

	// Implicitly solve.
	// This is a slight deviation from the original paper, which has parameters for
	// steps and the separate translation and rotation smoothing. For an artist, it's
	// easier to think in terms of the total desired amount of smoothing and the
	// number of steps as a precision parameter, rather than having to tune them in
	// tandem for each change.
	EigenSparse b( I + ( transSmooth / (double)steps ) * L /*transSmoothMap.asDiagonal()*/ );
	//EigenSparse c( I + ( rotSmooth / (double)steps ) * L /*rotSmoothMap.asDiagonal()*/ );

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
}

}
