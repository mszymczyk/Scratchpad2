//Maya ASCII 2018 scene
//Name: ddm_box_smooth_32_tri.ma
//Last modified: Wed, Jan 08, 2020 04:59:38 AM
//Codeset: 1250
requires maya "2018";
currentUnit -l centimeter -a degree -t film;
fileInfo "application" "maya";
fileInfo "product" "Maya 2018";
fileInfo "version" "2018";
fileInfo "cutIdentifier" "201706261615-f9658c4cfc";
fileInfo "osv" "Microsoft Windows 8 Business Edition, 64-bit  (Build 9200)\n";
createNode transform -s -n "persp";
	rename -uid "DC57263C-4F10-3E82-FD8A-1BA5AEA3FBCB";
	setAttr ".v" no;
	setAttr ".t" -type "double3" 0.18387573600068566 3.6805556679359364 4.7864207044031195 ;
	setAttr ".r" -type "double3" -37.538352729602359 2.2000000000000646 0 ;
createNode camera -s -n "perspShape" -p "persp";
	rename -uid "1503D24D-4FD6-167A-B705-A683F97EE8FB";
	setAttr -k off ".v" no;
	setAttr ".fl" 34.999999999999993;
	setAttr ".coi" 6.0407055441069071;
	setAttr ".imn" -type "string" "persp";
	setAttr ".den" -type "string" "persp_depth";
	setAttr ".man" -type "string" "persp_mask";
	setAttr ".hc" -type "string" "viewSet -p %camera";
createNode transform -s -n "top";
	rename -uid "629FE99D-415A-B8E7-33D5-77927B45C21A";
	setAttr ".v" no;
	setAttr ".t" -type "double3" 0 1000.1 0 ;
	setAttr ".r" -type "double3" -89.999999999999986 0 0 ;
createNode camera -s -n "topShape" -p "top";
	rename -uid "DB87D78F-4A45-4162-6294-D4A23F6D5850";
	setAttr -k off ".v" no;
	setAttr ".rnd" no;
	setAttr ".coi" 1000.1;
	setAttr ".ow" 30;
	setAttr ".imn" -type "string" "top";
	setAttr ".den" -type "string" "top_depth";
	setAttr ".man" -type "string" "top_mask";
	setAttr ".hc" -type "string" "viewSet -t %camera";
	setAttr ".o" yes;
createNode transform -s -n "front";
	rename -uid "5B9C25E7-47DC-C510-C782-6F9765E98182";
	setAttr ".v" no;
	setAttr ".t" -type "double3" 0 0 1000.1 ;
createNode camera -s -n "frontShape" -p "front";
	rename -uid "B345D6C2-4957-4E94-DA13-558B7AEEF36F";
	setAttr -k off ".v" no;
	setAttr ".rnd" no;
	setAttr ".coi" 1000.1;
	setAttr ".ow" 30;
	setAttr ".imn" -type "string" "front";
	setAttr ".den" -type "string" "front_depth";
	setAttr ".man" -type "string" "front_mask";
	setAttr ".hc" -type "string" "viewSet -f %camera";
	setAttr ".o" yes;
createNode transform -s -n "side";
	rename -uid "E765D5FC-4B30-B055-99AB-0091A1C45280";
	setAttr ".v" no;
	setAttr ".t" -type "double3" 1000.1 0 0 ;
	setAttr ".r" -type "double3" 0 89.999999999999986 0 ;
createNode camera -s -n "sideShape" -p "side";
	rename -uid "D73D900E-4256-4F12-BF70-AFB871360902";
	setAttr -k off ".v" no;
	setAttr ".rnd" no;
	setAttr ".coi" 1000.1;
	setAttr ".ow" 30;
	setAttr ".imn" -type "string" "side";
	setAttr ".den" -type "string" "side_depth";
	setAttr ".man" -type "string" "side_mask";
	setAttr ".hc" -type "string" "viewSet -s %camera";
	setAttr ".o" yes;
createNode joint -n "joint1";
	rename -uid "D57B63A5-416C-57CA-2F1F-A7B093067C43";
	addAttr -ci true -sn "liw" -ln "lockInfluenceWeights" -min 0 -max 1 -at "bool";
	setAttr ".uoc" 1;
	setAttr ".t" -type "double3" -1 0 0 ;
	setAttr ".mnrl" -type "double3" -360 -360 -360 ;
	setAttr ".mxrl" -type "double3" 360 360 360 ;
	setAttr ".bps" -type "matrix" 1 0 0 0 0 1 0 0 0 0 1 0 -1 0 0 1;
	setAttr ".radi" 2;
createNode joint -n "joint2" -p "joint1";
	rename -uid "6BE4A3AE-4184-11A3-EE16-ECA56076F2E7";
	addAttr -ci true -sn "liw" -ln "lockInfluenceWeights" -min 0 -max 1 -at "bool";
	setAttr ".uoc" 1;
	setAttr ".oc" 1;
	setAttr ".t" -type "double3" 1 0 1.1296519275560968e-14 ;
	setAttr ".mnrl" -type "double3" -360 -360 -360 ;
	setAttr ".mxrl" -type "double3" 360 360 360 ;
	setAttr ".jo" -type "double3" 0 1.5732396875363854 0 ;
	setAttr ".bps" -type "matrix" 0.99962304696860638 0 -0.027454762231703449 0 0 1 0 0
		 0.027454762231703449 0 0.99962304696860638 0 0 0 1.1296519275560968e-14 1;
	setAttr ".radi" 2;
createNode joint -n "joint3" -p "joint2";
	rename -uid "83D630FB-4218-D9D9-D930-818F4B84BDBE";
	addAttr -ci true -sn "liw" -ln "lockInfluenceWeights" -min 0 -max 1 -at "bool";
	setAttr ".uoc" 1;
	setAttr ".oc" 2;
	setAttr ".t" -type "double3" 1 0 3.7400638142059961e-15 ;
	setAttr ".mnrl" -type "double3" -360 -360 -360 ;
	setAttr ".mxrl" -type "double3" 360 360 360 ;
	setAttr ".bps" -type "matrix" 0.99962304696860638 0 -0.027454762231703449 0 0 1 0 0
		 0.027454762231703449 0 0.99962304696860638 0 0.99962304696860649 0 -0.027454762231688412 1;
	setAttr ".radi" 2;
createNode transform -n "pCube1";
	rename -uid "75BD5430-4277-33FA-3907-A580D5F567FA";
	setAttr -l on ".tx";
	setAttr -l on ".ty";
	setAttr -l on ".tz";
	setAttr -l on ".rx";
	setAttr -l on ".ry";
	setAttr -l on ".rz";
	setAttr -l on ".sx";
	setAttr -l on ".sy";
	setAttr -l on ".sz";
createNode mesh -n "pCubeShape1" -p "pCube1";
	rename -uid "10CBD6F1-4276-AD2E-FD97-B4B0E9FF4B64";
	setAttr -k off ".v";
	setAttr -s 4 ".iog[0].og";
	setAttr ".vir" yes;
	setAttr ".vif" yes;
	setAttr ".uvst[0].uvsn" -type "string" "map1";
	setAttr ".cuvs" -type "string" "map1";
	setAttr ".dcc" -type "string" "Ambient+Diffuse";
	setAttr ".covm[0]"  0 1 1;
	setAttr ".cdvm[0]"  0 1 1;
	setAttr ".vcs" 2;
createNode mesh -n "pCubeShape1Orig" -p "pCube1";
	rename -uid "BCDEC659-4A17-29DD-FAE1-72A4B3E717B9";
	setAttr -k off ".v";
	setAttr ".io" yes;
	setAttr ".vir" yes;
	setAttr ".vif" yes;
	setAttr ".uvst[0].uvsn" -type "string" "map1";
	setAttr -s 169 ".uvst[0].uvsp[0:168]" -type "float2" 0.375 0 0.3828125
		 0 0.390625 0 0.3984375 0 0.40625 0 0.4140625 0 0.421875 0 0.4296875 0 0.4375 0 0.4453125
		 0 0.453125 0 0.4609375 0 0.46875 0 0.4765625 0 0.484375 0 0.4921875 0 0.5 0 0.5078125
		 0 0.515625 0 0.5234375 0 0.53125 0 0.5390625 0 0.546875 0 0.5546875 0 0.5625 0 0.5703125
		 0 0.578125 0 0.5859375 0 0.59375 0 0.6015625 0 0.609375 0 0.6171875 0 0.625 0 0.375
		 0.25 0.3828125 0.25 0.390625 0.25 0.3984375 0.25 0.40625 0.25 0.4140625 0.25 0.421875
		 0.25 0.4296875 0.25 0.4375 0.25 0.4453125 0.25 0.453125 0.25 0.4609375 0.25 0.46875
		 0.25 0.4765625 0.25 0.484375 0.25 0.4921875 0.25 0.5 0.25 0.5078125 0.25 0.515625
		 0.25 0.5234375 0.25 0.53125 0.25 0.5390625 0.25 0.546875 0.25 0.5546875 0.25 0.5625
		 0.25 0.5703125 0.25 0.578125 0.25 0.5859375 0.25 0.59375 0.25 0.6015625 0.25 0.609375
		 0.25 0.6171875 0.25 0.625 0.25 0.375 0.5 0.3828125 0.5 0.390625 0.5 0.3984375 0.5
		 0.40625 0.5 0.4140625 0.5 0.421875 0.5 0.4296875 0.5 0.4375 0.5 0.4453125 0.5 0.453125
		 0.5 0.4609375 0.5 0.46875 0.5 0.4765625 0.5 0.484375 0.5 0.4921875 0.5 0.5 0.5 0.5078125
		 0.5 0.515625 0.5 0.5234375 0.5 0.53125 0.5 0.5390625 0.5 0.546875 0.5 0.5546875 0.5
		 0.5625 0.5 0.5703125 0.5 0.578125 0.5 0.5859375 0.5 0.59375 0.5 0.6015625 0.5 0.609375
		 0.5 0.6171875 0.5 0.625 0.5 0.375 0.75 0.3828125 0.75 0.390625 0.75 0.3984375 0.75
		 0.40625 0.75 0.4140625 0.75 0.421875 0.75 0.4296875 0.75 0.4375 0.75 0.4453125 0.75
		 0.453125 0.75 0.4609375 0.75 0.46875 0.75 0.4765625 0.75 0.484375 0.75 0.4921875
		 0.75 0.5 0.75 0.5078125 0.75 0.515625 0.75 0.5234375 0.75 0.53125 0.75 0.5390625
		 0.75 0.546875 0.75 0.5546875 0.75 0.5625 0.75 0.5703125 0.75 0.578125 0.75 0.5859375
		 0.75 0.59375 0.75 0.6015625 0.75 0.609375 0.75 0.6171875 0.75 0.625 0.75 0.375 1
		 0.3828125 1 0.390625 1 0.3984375 1 0.40625 1 0.4140625 1 0.421875 1 0.4296875 1 0.4375
		 1 0.4453125 1 0.453125 1 0.4609375 1 0.46875 1 0.4765625 1 0.484375 1 0.4921875 1
		 0.5 1 0.5078125 1 0.515625 1 0.5234375 1 0.53125 1 0.5390625 1 0.546875 1 0.5546875
		 1 0.5625 1 0.5703125 1 0.578125 1 0.5859375 1 0.59375 1 0.6015625 1 0.609375 1 0.6171875
		 1 0.625 1 0.875 0 0.875 0.25 0.125 0 0.125 0.25;
	setAttr ".cuvs" -type "string" "map1";
	setAttr ".dcc" -type "string" "Ambient+Diffuse";
	setAttr ".covm[0]"  0 1 1;
	setAttr ".cdvm[0]"  0 1 1;
	setAttr -s 132 ".vt[0:131]"  -2 -0.5 0.5 -1.875 -0.5 0.5 -1.75 -0.5 0.5
		 -1.625 -0.5 0.5 -1.5 -0.5 0.5 -1.375 -0.5 0.5 -1.25 -0.5 0.5 -1.125 -0.5 0.5 -1 -0.5 0.5
		 -0.875 -0.5 0.5 -0.75 -0.5 0.5 -0.625 -0.5 0.5 -0.5 -0.5 0.5 -0.375 -0.5 0.5 -0.25 -0.5 0.5
		 -0.125 -0.5 0.5 0 -0.5 0.5 0.125 -0.5 0.5 0.25 -0.5 0.5 0.375 -0.5 0.5 0.5 -0.5 0.5
		 0.625 -0.5 0.5 0.75 -0.5 0.5 0.875 -0.5 0.5 1 -0.5 0.5 1.125 -0.5 0.5 1.25 -0.5 0.5
		 1.375 -0.5 0.5 1.5 -0.5 0.5 1.625 -0.5 0.5 1.75 -0.5 0.5 1.875 -0.5 0.5 2 -0.5 0.5
		 -2 0.5 0.5 -1.875 0.5 0.5 -1.75 0.5 0.5 -1.625 0.5 0.5 -1.5 0.5 0.5 -1.375 0.5 0.5
		 -1.25 0.5 0.5 -1.125 0.5 0.5 -1 0.5 0.5 -0.875 0.5 0.5 -0.75 0.5 0.5 -0.625 0.5 0.5
		 -0.5 0.5 0.5 -0.375 0.5 0.5 -0.25 0.5 0.5 -0.125 0.5 0.5 0 0.5 0.5 0.125 0.5 0.5
		 0.25 0.5 0.5 0.375 0.5 0.5 0.5 0.5 0.5 0.625 0.5 0.5 0.75 0.5 0.5 0.875 0.5 0.5 1 0.5 0.5
		 1.125 0.5 0.5 1.25 0.5 0.5 1.375 0.5 0.5 1.5 0.5 0.5 1.625 0.5 0.5 1.75 0.5 0.5 1.875 0.5 0.5
		 2 0.5 0.5 -2 0.5 -0.5 -1.875 0.5 -0.5 -1.75 0.5 -0.5 -1.625 0.5 -0.5 -1.5 0.5 -0.5
		 -1.375 0.5 -0.5 -1.25 0.5 -0.5 -1.125 0.5 -0.5 -1 0.5 -0.5 -0.875 0.5 -0.5 -0.75 0.5 -0.5
		 -0.625 0.5 -0.5 -0.5 0.5 -0.5 -0.375 0.5 -0.5 -0.25 0.5 -0.5 -0.125 0.5 -0.5 0 0.5 -0.5
		 0.125 0.5 -0.5 0.25 0.5 -0.5 0.375 0.5 -0.5 0.5 0.5 -0.5 0.625 0.5 -0.5 0.75 0.5 -0.5
		 0.875 0.5 -0.5 1 0.5 -0.5 1.125 0.5 -0.5 1.25 0.5 -0.5 1.375 0.5 -0.5 1.5 0.5 -0.5
		 1.625 0.5 -0.5 1.75 0.5 -0.5 1.875 0.5 -0.5 2 0.5 -0.5 -2 -0.5 -0.5 -1.875 -0.5 -0.5
		 -1.75 -0.5 -0.5 -1.625 -0.5 -0.5 -1.5 -0.5 -0.5 -1.375 -0.5 -0.5 -1.25 -0.5 -0.5
		 -1.125 -0.5 -0.5 -1 -0.5 -0.5 -0.875 -0.5 -0.5 -0.75 -0.5 -0.5 -0.625 -0.5 -0.5 -0.5 -0.5 -0.5
		 -0.375 -0.5 -0.5 -0.25 -0.5 -0.5 -0.125 -0.5 -0.5 0 -0.5 -0.5 0.125 -0.5 -0.5 0.25 -0.5 -0.5
		 0.375 -0.5 -0.5 0.5 -0.5 -0.5 0.625 -0.5 -0.5 0.75 -0.5 -0.5 0.875 -0.5 -0.5 1 -0.5 -0.5
		 1.125 -0.5 -0.5 1.25 -0.5 -0.5 1.375 -0.5 -0.5 1.5 -0.5 -0.5 1.625 -0.5 -0.5 1.75 -0.5 -0.5
		 1.875 -0.5 -0.5 2 -0.5 -0.5;
	setAttr -s 390 ".ed";
	setAttr ".ed[0:165]"  0 1 0 1 2 0 2 3 0 3 4 0 4 5 0 5 6 0 6 7 0 7 8 0 8 9 0
		 9 10 0 10 11 0 11 12 0 12 13 0 13 14 0 14 15 0 15 16 0 16 17 0 17 18 0 18 19 0 19 20 0
		 20 21 0 21 22 0 22 23 0 23 24 0 24 25 0 25 26 0 26 27 0 27 28 0 28 29 0 29 30 0 30 31 0
		 31 32 0 33 34 0 34 35 0 35 36 0 36 37 0 37 38 0 38 39 0 39 40 0 40 41 0 41 42 0 42 43 0
		 43 44 0 44 45 0 45 46 0 46 47 0 47 48 0 48 49 0 49 50 0 50 51 0 51 52 0 52 53 0 53 54 0
		 54 55 0 55 56 0 56 57 0 57 58 0 58 59 0 59 60 0 60 61 0 61 62 0 62 63 0 63 64 0 64 65 0
		 66 67 0 67 68 0 68 69 0 69 70 0 70 71 0 71 72 0 72 73 0 73 74 0 74 75 0 75 76 0 76 77 0
		 77 78 0 78 79 0 79 80 0 80 81 0 81 82 0 82 83 0 83 84 0 84 85 0 85 86 0 86 87 0 87 88 0
		 88 89 0 89 90 0 90 91 0 91 92 0 92 93 0 93 94 0 94 95 0 95 96 0 96 97 0 97 98 0 99 100 0
		 100 101 0 101 102 0 102 103 0 103 104 0 104 105 0 105 106 0 106 107 0 107 108 0 108 109 0
		 109 110 0 110 111 0 111 112 0 112 113 0 113 114 0 114 115 0 115 116 0 116 117 0 117 118 0
		 118 119 0 119 120 0 120 121 0 121 122 0 122 123 0 123 124 0 124 125 0 125 126 0 126 127 0
		 127 128 0 128 129 0 129 130 0 130 131 0 0 33 0 1 34 1 2 35 1 3 36 1 4 37 1 5 38 1
		 6 39 1 7 40 1 8 41 1 9 42 1 10 43 1 11 44 1 12 45 1 13 46 1 14 47 1 15 48 1 16 49 1
		 17 50 1 18 51 1 19 52 1 20 53 1 21 54 1 22 55 1 23 56 1 24 57 1 25 58 1 26 59 1 27 60 1
		 28 61 1 29 62 1 30 63 1 31 64 1 32 65 0 33 66 0 34 67 1 35 68 1 36 69 1 37 70 1;
	setAttr ".ed[166:331]" 38 71 1 39 72 1 40 73 1 41 74 1 42 75 1 43 76 1 44 77 1
		 45 78 1 46 79 1 47 80 1 48 81 1 49 82 1 50 83 1 51 84 1 52 85 1 53 86 1 54 87 1 55 88 1
		 56 89 1 57 90 1 58 91 1 59 92 1 60 93 1 61 94 1 62 95 1 63 96 1 64 97 1 65 98 0 66 99 0
		 67 100 1 68 101 1 69 102 1 70 103 1 71 104 1 72 105 1 73 106 1 74 107 1 75 108 1
		 76 109 1 77 110 1 78 111 1 79 112 1 80 113 1 81 114 1 82 115 1 83 116 1 84 117 1
		 85 118 1 86 119 1 87 120 1 88 121 1 89 122 1 90 123 1 91 124 1 92 125 1 93 126 1
		 94 127 1 95 128 1 96 129 1 97 130 1 98 131 0 99 0 0 100 1 1 101 2 1 102 3 1 103 4 1
		 104 5 1 105 6 1 106 7 1 107 8 1 108 9 1 109 10 1 110 11 1 111 12 1 112 13 1 113 14 1
		 114 15 1 115 16 1 116 17 1 117 18 1 118 19 1 119 20 1 120 21 1 121 22 1 122 23 1
		 123 24 1 124 25 1 125 26 1 126 27 1 127 28 1 128 29 1 129 30 1 130 31 1 131 32 0
		 1 33 1 2 34 1 3 35 1 4 36 1 5 37 1 6 38 1 7 39 1 8 40 1 9 41 1 10 42 1 11 43 1 12 44 1
		 13 45 1 14 46 1 15 47 1 16 48 1 17 49 1 18 50 1 19 51 1 20 52 1 21 53 1 22 54 1 23 55 1
		 24 56 1 25 57 1 26 58 1 27 59 1 28 60 1 29 61 1 30 62 1 31 63 1 32 64 1 34 66 1 35 67 1
		 36 68 1 37 69 1 38 70 1 39 71 1 40 72 1 41 73 1 42 74 1 43 75 1 44 76 1 45 77 1 46 78 1
		 47 79 1 48 80 1 49 81 1 50 82 1 51 83 1 52 84 1 53 85 1 54 86 1 55 87 1 56 88 1 57 89 1
		 58 90 1 59 91 1 60 92 1 61 93 1 62 94 1 63 95 1 64 96 1 65 97 1 67 99 1 68 100 1
		 69 101 1 70 102 1 71 103 1 72 104 1 73 105 1 74 106 1;
	setAttr ".ed[332:389]" 75 107 1 76 108 1 77 109 1 78 110 1 79 111 1 80 112 1
		 81 113 1 82 114 1 83 115 1 84 116 1 85 117 1 86 118 1 87 119 1 88 120 1 89 121 1
		 90 122 1 91 123 1 92 124 1 93 125 1 94 126 1 95 127 1 96 128 1 97 129 1 98 130 1
		 100 0 1 101 1 1 102 2 1 103 3 1 104 4 1 105 5 1 106 6 1 107 7 1 108 8 1 109 9 1 110 10 1
		 111 11 1 112 12 1 113 13 1 114 14 1 115 15 1 116 16 1 117 17 1 118 18 1 119 19 1
		 120 20 1 121 21 1 122 22 1 123 23 1 124 24 1 125 25 1 126 26 1 127 27 1 128 28 1
		 129 29 1 130 30 1 131 31 1 131 65 1 0 66 1;
	setAttr -s 260 -ch 780 ".fc[0:259]" -type "polyFaces" 
		f 3 0 260 -129
		mu 0 3 0 1 33
		f 3 -261 129 -33
		mu 0 3 33 1 34
		f 3 1 261 -130
		mu 0 3 1 2 34
		f 3 -262 130 -34
		mu 0 3 34 2 35
		f 3 2 262 -131
		mu 0 3 2 3 35
		f 3 -263 131 -35
		mu 0 3 35 3 36
		f 3 3 263 -132
		mu 0 3 3 4 36
		f 3 -264 132 -36
		mu 0 3 36 4 37
		f 3 4 264 -133
		mu 0 3 4 5 37
		f 3 -265 133 -37
		mu 0 3 37 5 38
		f 3 5 265 -134
		mu 0 3 5 6 38
		f 3 -266 134 -38
		mu 0 3 38 6 39
		f 3 6 266 -135
		mu 0 3 6 7 39
		f 3 -267 135 -39
		mu 0 3 39 7 40
		f 3 7 267 -136
		mu 0 3 7 8 40
		f 3 -268 136 -40
		mu 0 3 40 8 41
		f 3 8 268 -137
		mu 0 3 8 9 41
		f 3 -269 137 -41
		mu 0 3 41 9 42
		f 3 9 269 -138
		mu 0 3 9 10 42
		f 3 -270 138 -42
		mu 0 3 42 10 43
		f 3 10 270 -139
		mu 0 3 10 11 43
		f 3 -271 139 -43
		mu 0 3 43 11 44
		f 3 11 271 -140
		mu 0 3 11 12 44
		f 3 -272 140 -44
		mu 0 3 44 12 45
		f 3 12 272 -141
		mu 0 3 12 13 45
		f 3 -273 141 -45
		mu 0 3 45 13 46
		f 3 13 273 -142
		mu 0 3 13 14 46
		f 3 -274 142 -46
		mu 0 3 46 14 47
		f 3 14 274 -143
		mu 0 3 14 15 47
		f 3 -275 143 -47
		mu 0 3 47 15 48
		f 3 15 275 -144
		mu 0 3 15 16 48
		f 3 -276 144 -48
		mu 0 3 48 16 49
		f 3 16 276 -145
		mu 0 3 16 17 49
		f 3 -277 145 -49
		mu 0 3 49 17 50
		f 3 17 277 -146
		mu 0 3 17 18 50
		f 3 -278 146 -50
		mu 0 3 50 18 51
		f 3 18 278 -147
		mu 0 3 18 19 51
		f 3 -279 147 -51
		mu 0 3 51 19 52
		f 3 19 279 -148
		mu 0 3 19 20 52
		f 3 -280 148 -52
		mu 0 3 52 20 53
		f 3 20 280 -149
		mu 0 3 20 21 53
		f 3 -281 149 -53
		mu 0 3 53 21 54
		f 3 21 281 -150
		mu 0 3 21 22 54
		f 3 -282 150 -54
		mu 0 3 54 22 55
		f 3 22 282 -151
		mu 0 3 22 23 55
		f 3 -283 151 -55
		mu 0 3 55 23 56
		f 3 23 283 -152
		mu 0 3 23 24 56
		f 3 -284 152 -56
		mu 0 3 56 24 57
		f 3 24 284 -153
		mu 0 3 24 25 57
		f 3 -285 153 -57
		mu 0 3 57 25 58
		f 3 25 285 -154
		mu 0 3 25 26 58
		f 3 -286 154 -58
		mu 0 3 58 26 59
		f 3 26 286 -155
		mu 0 3 26 27 59
		f 3 -287 155 -59
		mu 0 3 59 27 60
		f 3 27 287 -156
		mu 0 3 27 28 60
		f 3 -288 156 -60
		mu 0 3 60 28 61
		f 3 28 288 -157
		mu 0 3 28 29 61
		f 3 -289 157 -61
		mu 0 3 61 29 62
		f 3 29 289 -158
		mu 0 3 29 30 62
		f 3 -290 158 -62
		mu 0 3 62 30 63
		f 3 30 290 -159
		mu 0 3 30 31 63
		f 3 -291 159 -63
		mu 0 3 63 31 64
		f 3 31 291 -160
		mu 0 3 31 32 64
		f 3 -292 160 -64
		mu 0 3 64 32 65
		f 3 32 292 -162
		mu 0 3 33 34 66
		f 3 -293 162 -65
		mu 0 3 66 34 67
		f 3 33 293 -163
		mu 0 3 34 35 67
		f 3 -294 163 -66
		mu 0 3 67 35 68
		f 3 34 294 -164
		mu 0 3 35 36 68
		f 3 -295 164 -67
		mu 0 3 68 36 69
		f 3 35 295 -165
		mu 0 3 36 37 69
		f 3 -296 165 -68
		mu 0 3 69 37 70
		f 3 36 296 -166
		mu 0 3 37 38 70
		f 3 -297 166 -69
		mu 0 3 70 38 71
		f 3 37 297 -167
		mu 0 3 38 39 71
		f 3 -298 167 -70
		mu 0 3 71 39 72
		f 3 38 298 -168
		mu 0 3 39 40 72
		f 3 -299 168 -71
		mu 0 3 72 40 73
		f 3 39 299 -169
		mu 0 3 40 41 73
		f 3 -300 169 -72
		mu 0 3 73 41 74
		f 3 40 300 -170
		mu 0 3 41 42 74
		f 3 -301 170 -73
		mu 0 3 74 42 75
		f 3 41 301 -171
		mu 0 3 42 43 75
		f 3 -302 171 -74
		mu 0 3 75 43 76
		f 3 42 302 -172
		mu 0 3 43 44 76
		f 3 -303 172 -75
		mu 0 3 76 44 77
		f 3 43 303 -173
		mu 0 3 44 45 77
		f 3 -304 173 -76
		mu 0 3 77 45 78
		f 3 44 304 -174
		mu 0 3 45 46 78
		f 3 -305 174 -77
		mu 0 3 78 46 79
		f 3 45 305 -175
		mu 0 3 46 47 79
		f 3 -306 175 -78
		mu 0 3 79 47 80
		f 3 46 306 -176
		mu 0 3 47 48 80
		f 3 -307 176 -79
		mu 0 3 80 48 81
		f 3 47 307 -177
		mu 0 3 48 49 81
		f 3 -308 177 -80
		mu 0 3 81 49 82
		f 3 48 308 -178
		mu 0 3 49 50 82
		f 3 -309 178 -81
		mu 0 3 82 50 83
		f 3 49 309 -179
		mu 0 3 50 51 83
		f 3 -310 179 -82
		mu 0 3 83 51 84
		f 3 50 310 -180
		mu 0 3 51 52 84
		f 3 -311 180 -83
		mu 0 3 84 52 85
		f 3 51 311 -181
		mu 0 3 52 53 85
		f 3 -312 181 -84
		mu 0 3 85 53 86
		f 3 52 312 -182
		mu 0 3 53 54 86
		f 3 -313 182 -85
		mu 0 3 86 54 87
		f 3 53 313 -183
		mu 0 3 54 55 87
		f 3 -314 183 -86
		mu 0 3 87 55 88
		f 3 54 314 -184
		mu 0 3 55 56 88
		f 3 -315 184 -87
		mu 0 3 88 56 89
		f 3 55 315 -185
		mu 0 3 56 57 89
		f 3 -316 185 -88
		mu 0 3 89 57 90
		f 3 56 316 -186
		mu 0 3 57 58 90
		f 3 -317 186 -89
		mu 0 3 90 58 91
		f 3 57 317 -187
		mu 0 3 58 59 91
		f 3 -318 187 -90
		mu 0 3 91 59 92
		f 3 58 318 -188
		mu 0 3 59 60 92
		f 3 -319 188 -91
		mu 0 3 92 60 93
		f 3 59 319 -189
		mu 0 3 60 61 93
		f 3 -320 189 -92
		mu 0 3 93 61 94
		f 3 60 320 -190
		mu 0 3 61 62 94
		f 3 -321 190 -93
		mu 0 3 94 62 95
		f 3 61 321 -191
		mu 0 3 62 63 95
		f 3 -322 191 -94
		mu 0 3 95 63 96
		f 3 62 322 -192
		mu 0 3 63 64 96
		f 3 -323 192 -95
		mu 0 3 96 64 97
		f 3 63 323 -193
		mu 0 3 64 65 97
		f 3 -324 193 -96
		mu 0 3 97 65 98
		f 3 64 324 -195
		mu 0 3 66 67 99
		f 3 -325 195 -97
		mu 0 3 99 67 100
		f 3 65 325 -196
		mu 0 3 67 68 100
		f 3 -326 196 -98
		mu 0 3 100 68 101
		f 3 66 326 -197
		mu 0 3 68 69 101
		f 3 -327 197 -99
		mu 0 3 101 69 102
		f 3 67 327 -198
		mu 0 3 69 70 102
		f 3 -328 198 -100
		mu 0 3 102 70 103
		f 3 68 328 -199
		mu 0 3 70 71 103
		f 3 -329 199 -101
		mu 0 3 103 71 104
		f 3 69 329 -200
		mu 0 3 71 72 104
		f 3 -330 200 -102
		mu 0 3 104 72 105
		f 3 70 330 -201
		mu 0 3 72 73 105
		f 3 -331 201 -103
		mu 0 3 105 73 106
		f 3 71 331 -202
		mu 0 3 73 74 106
		f 3 -332 202 -104
		mu 0 3 106 74 107
		f 3 72 332 -203
		mu 0 3 74 75 107
		f 3 -333 203 -105
		mu 0 3 107 75 108
		f 3 73 333 -204
		mu 0 3 75 76 108
		f 3 -334 204 -106
		mu 0 3 108 76 109
		f 3 74 334 -205
		mu 0 3 76 77 109
		f 3 -335 205 -107
		mu 0 3 109 77 110
		f 3 75 335 -206
		mu 0 3 77 78 110
		f 3 -336 206 -108
		mu 0 3 110 78 111
		f 3 76 336 -207
		mu 0 3 78 79 111
		f 3 -337 207 -109
		mu 0 3 111 79 112
		f 3 77 337 -208
		mu 0 3 79 80 112
		f 3 -338 208 -110
		mu 0 3 112 80 113
		f 3 78 338 -209
		mu 0 3 80 81 113
		f 3 -339 209 -111
		mu 0 3 113 81 114
		f 3 79 339 -210
		mu 0 3 81 82 114
		f 3 -340 210 -112
		mu 0 3 114 82 115
		f 3 80 340 -211
		mu 0 3 82 83 115
		f 3 -341 211 -113
		mu 0 3 115 83 116
		f 3 81 341 -212
		mu 0 3 83 84 116
		f 3 -342 212 -114
		mu 0 3 116 84 117
		f 3 82 342 -213
		mu 0 3 84 85 117
		f 3 -343 213 -115
		mu 0 3 117 85 118
		f 3 83 343 -214
		mu 0 3 85 86 118
		f 3 -344 214 -116
		mu 0 3 118 86 119
		f 3 84 344 -215
		mu 0 3 86 87 119
		f 3 -345 215 -117
		mu 0 3 119 87 120
		f 3 85 345 -216
		mu 0 3 87 88 120
		f 3 -346 216 -118
		mu 0 3 120 88 121
		f 3 86 346 -217
		mu 0 3 88 89 121
		f 3 -347 217 -119
		mu 0 3 121 89 122
		f 3 87 347 -218
		mu 0 3 89 90 122
		f 3 -348 218 -120
		mu 0 3 122 90 123
		f 3 88 348 -219
		mu 0 3 90 91 123
		f 3 -349 219 -121
		mu 0 3 123 91 124
		f 3 89 349 -220
		mu 0 3 91 92 124
		f 3 -350 220 -122
		mu 0 3 124 92 125
		f 3 90 350 -221
		mu 0 3 92 93 125
		f 3 -351 221 -123
		mu 0 3 125 93 126
		f 3 91 351 -222
		mu 0 3 93 94 126
		f 3 -352 222 -124
		mu 0 3 126 94 127
		f 3 92 352 -223
		mu 0 3 94 95 127
		f 3 -353 223 -125
		mu 0 3 127 95 128
		f 3 93 353 -224
		mu 0 3 95 96 128
		f 3 -354 224 -126
		mu 0 3 128 96 129
		f 3 94 354 -225
		mu 0 3 96 97 129
		f 3 -355 225 -127
		mu 0 3 129 97 130
		f 3 95 355 -226
		mu 0 3 97 98 130
		f 3 -356 226 -128
		mu 0 3 130 98 131
		f 3 96 356 -228
		mu 0 3 99 100 132
		f 3 -357 228 -1
		mu 0 3 132 100 133
		f 3 97 357 -229
		mu 0 3 100 101 133
		f 3 -358 229 -2
		mu 0 3 133 101 134
		f 3 98 358 -230
		mu 0 3 101 102 134
		f 3 -359 230 -3
		mu 0 3 134 102 135
		f 3 99 359 -231
		mu 0 3 102 103 135
		f 3 -360 231 -4
		mu 0 3 135 103 136
		f 3 100 360 -232
		mu 0 3 103 104 136
		f 3 -361 232 -5
		mu 0 3 136 104 137
		f 3 101 361 -233
		mu 0 3 104 105 137
		f 3 -362 233 -6
		mu 0 3 137 105 138
		f 3 102 362 -234
		mu 0 3 105 106 138
		f 3 -363 234 -7
		mu 0 3 138 106 139
		f 3 103 363 -235
		mu 0 3 106 107 139
		f 3 -364 235 -8
		mu 0 3 139 107 140
		f 3 104 364 -236
		mu 0 3 107 108 140
		f 3 -365 236 -9
		mu 0 3 140 108 141
		f 3 105 365 -237
		mu 0 3 108 109 141
		f 3 -366 237 -10
		mu 0 3 141 109 142
		f 3 106 366 -238
		mu 0 3 109 110 142
		f 3 -367 238 -11
		mu 0 3 142 110 143
		f 3 107 367 -239
		mu 0 3 110 111 143
		f 3 -368 239 -12
		mu 0 3 143 111 144
		f 3 108 368 -240
		mu 0 3 111 112 144
		f 3 -369 240 -13
		mu 0 3 144 112 145
		f 3 109 369 -241
		mu 0 3 112 113 145
		f 3 -370 241 -14
		mu 0 3 145 113 146
		f 3 110 370 -242
		mu 0 3 113 114 146
		f 3 -371 242 -15
		mu 0 3 146 114 147
		f 3 111 371 -243
		mu 0 3 114 115 147
		f 3 -372 243 -16
		mu 0 3 147 115 148
		f 3 112 372 -244
		mu 0 3 115 116 148
		f 3 -373 244 -17
		mu 0 3 148 116 149
		f 3 113 373 -245
		mu 0 3 116 117 149
		f 3 -374 245 -18
		mu 0 3 149 117 150
		f 3 114 374 -246
		mu 0 3 117 118 150
		f 3 -375 246 -19
		mu 0 3 150 118 151
		f 3 115 375 -247
		mu 0 3 118 119 151
		f 3 -376 247 -20
		mu 0 3 151 119 152
		f 3 116 376 -248
		mu 0 3 119 120 152
		f 3 -377 248 -21
		mu 0 3 152 120 153
		f 3 117 377 -249
		mu 0 3 120 121 153
		f 3 -378 249 -22
		mu 0 3 153 121 154
		f 3 118 378 -250
		mu 0 3 121 122 154
		f 3 -379 250 -23
		mu 0 3 154 122 155
		f 3 119 379 -251
		mu 0 3 122 123 155
		f 3 -380 251 -24
		mu 0 3 155 123 156
		f 3 120 380 -252
		mu 0 3 123 124 156
		f 3 -381 252 -25
		mu 0 3 156 124 157
		f 3 121 381 -253
		mu 0 3 124 125 157
		f 3 -382 253 -26
		mu 0 3 157 125 158
		f 3 122 382 -254
		mu 0 3 125 126 158
		f 3 -383 254 -27
		mu 0 3 158 126 159
		f 3 123 383 -255
		mu 0 3 126 127 159
		f 3 -384 255 -28
		mu 0 3 159 127 160
		f 3 124 384 -256
		mu 0 3 127 128 160
		f 3 -385 256 -29
		mu 0 3 160 128 161
		f 3 125 385 -257
		mu 0 3 128 129 161
		f 3 -386 257 -30
		mu 0 3 161 129 162
		f 3 126 386 -258
		mu 0 3 129 130 162
		f 3 -387 258 -31
		mu 0 3 162 130 163
		f 3 127 387 -259
		mu 0 3 130 131 163
		f 3 -388 259 -32
		mu 0 3 163 131 164
		f 3 -260 388 -161
		mu 0 3 32 165 65
		f 3 -389 -227 -194
		mu 0 3 65 165 166
		f 3 227 389 194
		mu 0 3 167 0 168
		f 3 -390 128 161
		mu 0 3 168 0 33;
	setAttr ".cd" -type "dataPolyComponent" Index_Data Edge 0 ;
	setAttr ".cvd" -type "dataPolyComponent" Index_Data Vertex 0 ;
	setAttr ".pd[0]" -type "dataPolyComponent" Index_Data UV 0 ;
	setAttr ".hfd" -type "dataPolyComponent" Index_Data Face 0 ;
	setAttr ".vcs" 2;
createNode lightLinker -s -n "lightLinker1";
	rename -uid "855BF788-4580-1FE4-9B15-AFA89394FC22";
	setAttr -s 2 ".lnk";
	setAttr -s 2 ".slnk";
createNode shapeEditorManager -n "shapeEditorManager";
	rename -uid "FB251BFC-49E5-1802-32F6-2FB04565CCA1";
createNode poseInterpolatorManager -n "poseInterpolatorManager";
	rename -uid "D0E77137-4C36-42E1-F54C-7FB1828C6737";
createNode displayLayerManager -n "layerManager";
	rename -uid "4C50AB97-4292-D759-2D28-3DB0D9B70F1D";
createNode displayLayer -n "defaultLayer";
	rename -uid "C71FD887-42EF-BD26-F225-2C96CEFBED45";
createNode renderLayerManager -n "renderLayerManager";
	rename -uid "6B60FE0B-4E2C-F7F4-DA10-11AD6A3771CB";
createNode renderLayer -n "defaultRenderLayer";
	rename -uid "ED7DDB02-47FA-7333-763D-73BFCE474417";
	setAttr ".g" yes;
createNode animCurveTA -n "pasted__joint2_rotateX";
	rename -uid "3D2BF1F9-4FA4-F31B-F228-D7BF13A1E55B";
	setAttr ".tan" 18;
	setAttr ".wgt" no;
	setAttr -s 2 ".ktv[0:1]"  1 0 30 0;
createNode animCurveTA -n "pasted__joint2_rotateY";
	rename -uid "27E52777-45B7-9199-B5CB-5CB854962AD3";
	setAttr ".tan" 18;
	setAttr ".wgt" no;
	setAttr -s 2 ".ktv[0:1]"  1 0 30 0;
createNode animCurveTA -n "pasted__joint2_rotateZ";
	rename -uid "6A376AB5-438F-951A-83EB-40B27D0CCD29";
	setAttr ".tan" 18;
	setAttr ".wgt" no;
	setAttr -s 2 ".ktv[0:1]"  1 0 30 90;
createNode script -n "uiConfigurationScriptNode";
	rename -uid "CB4323D5-48B6-E1F2-74EC-068F148B88BC";
	setAttr ".b" -type "string" (
		"// Maya Mel UI Configuration File.\n//\n//  This script is machine generated.  Edit at your own risk.\n//\n//\n\nglobal string $gMainPane;\nif (`paneLayout -exists $gMainPane`) {\n\n\tglobal int $gUseScenePanelConfig;\n\tint    $useSceneConfig = $gUseScenePanelConfig;\n\tint    $menusOkayInPanels = `optionVar -q allowMenusInPanels`;\tint    $nVisPanes = `paneLayout -q -nvp $gMainPane`;\n\tint    $nPanes = 0;\n\tstring $editorName;\n\tstring $panelName;\n\tstring $itemFilterName;\n\tstring $panelConfig;\n\n\t//\n\t//  get current state of the UI\n\t//\n\tsceneUIReplacement -update $gMainPane;\n\n\t$panelName = `sceneUIReplacement -getNextPanel \"modelPanel\" (localizedPanelLabel(\"Top View\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tmodelPanel -edit -l (localizedPanelLabel(\"Top View\")) -mbv $menusOkayInPanels  $panelName;\n\t\t$editorName = $panelName;\n        modelEditor -e \n            -camera \"top\" \n            -useInteractiveMode 0\n            -displayLights \"default\" \n            -displayAppearance \"smoothShaded\" \n            -activeOnly 0\n"
		+ "            -ignorePanZoom 0\n            -wireframeOnShaded 0\n            -headsUpDisplay 1\n            -holdOuts 1\n            -selectionHiliteDisplay 1\n            -useDefaultMaterial 0\n            -bufferMode \"double\" \n            -twoSidedLighting 0\n            -backfaceCulling 0\n            -xray 0\n            -jointXray 0\n            -activeComponentsXray 0\n            -displayTextures 0\n            -smoothWireframe 0\n            -lineWidth 1\n            -textureAnisotropic 0\n            -textureHilight 1\n            -textureSampling 2\n            -textureDisplay \"modulate\" \n            -textureMaxSize 16384\n            -fogging 0\n            -fogSource \"fragment\" \n            -fogMode \"linear\" \n            -fogStart 0\n            -fogEnd 100\n            -fogDensity 0.1\n            -fogColor 0.5 0.5 0.5 1 \n            -depthOfFieldPreview 1\n            -maxConstantTransparency 1\n            -rendererName \"vp2Renderer\" \n            -objectFilterShowInHUD 1\n            -isFiltered 0\n            -colorResolution 256 256 \n"
		+ "            -bumpResolution 512 512 \n            -textureCompression 0\n            -transparencyAlgorithm \"frontAndBackCull\" \n            -transpInShadows 0\n            -cullingOverride \"none\" \n            -lowQualityLighting 0\n            -maximumNumHardwareLights 1\n            -occlusionCulling 0\n            -shadingModel 0\n            -useBaseRenderer 0\n            -useReducedRenderer 0\n            -smallObjectCulling 0\n            -smallObjectThreshold -1 \n            -interactiveDisableShadows 0\n            -interactiveBackFaceCull 0\n            -sortTransparent 1\n            -controllers 1\n            -nurbsCurves 1\n            -nurbsSurfaces 1\n            -polymeshes 1\n            -subdivSurfaces 1\n            -planes 1\n            -lights 1\n            -cameras 1\n            -controlVertices 1\n            -hulls 1\n            -grid 1\n            -imagePlane 1\n            -joints 1\n            -ikHandles 1\n            -deformers 1\n            -dynamics 1\n            -particleInstancers 1\n            -fluids 1\n"
		+ "            -hairSystems 1\n            -follicles 1\n            -nCloths 1\n            -nParticles 1\n            -nRigids 1\n            -dynamicConstraints 1\n            -locators 1\n            -manipulators 1\n            -pluginShapes 1\n            -dimensions 1\n            -handles 1\n            -pivots 1\n            -textures 1\n            -strokes 1\n            -motionTrails 1\n            -clipGhosts 1\n            -greasePencils 1\n            -shadows 0\n            -captureSequenceNumber -1\n            -width 1\n            -height 1\n            -sceneRenderFilter 0\n            $editorName;\n        modelEditor -e -viewSelected 0 $editorName;\n        modelEditor -e \n            -pluginObjects \"gpuCacheDisplayFilter\" 1 \n            $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextPanel \"modelPanel\" (localizedPanelLabel(\"Side View\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tmodelPanel -edit -l (localizedPanelLabel(\"Side View\")) -mbv $menusOkayInPanels  $panelName;\n"
		+ "\t\t$editorName = $panelName;\n        modelEditor -e \n            -camera \"side\" \n            -useInteractiveMode 0\n            -displayLights \"default\" \n            -displayAppearance \"smoothShaded\" \n            -activeOnly 0\n            -ignorePanZoom 0\n            -wireframeOnShaded 0\n            -headsUpDisplay 1\n            -holdOuts 1\n            -selectionHiliteDisplay 1\n            -useDefaultMaterial 0\n            -bufferMode \"double\" \n            -twoSidedLighting 0\n            -backfaceCulling 0\n            -xray 0\n            -jointXray 0\n            -activeComponentsXray 0\n            -displayTextures 0\n            -smoothWireframe 0\n            -lineWidth 1\n            -textureAnisotropic 0\n            -textureHilight 1\n            -textureSampling 2\n            -textureDisplay \"modulate\" \n            -textureMaxSize 16384\n            -fogging 0\n            -fogSource \"fragment\" \n            -fogMode \"linear\" \n            -fogStart 0\n            -fogEnd 100\n            -fogDensity 0.1\n            -fogColor 0.5 0.5 0.5 1 \n"
		+ "            -depthOfFieldPreview 1\n            -maxConstantTransparency 1\n            -rendererName \"vp2Renderer\" \n            -objectFilterShowInHUD 1\n            -isFiltered 0\n            -colorResolution 256 256 \n            -bumpResolution 512 512 \n            -textureCompression 0\n            -transparencyAlgorithm \"frontAndBackCull\" \n            -transpInShadows 0\n            -cullingOverride \"none\" \n            -lowQualityLighting 0\n            -maximumNumHardwareLights 1\n            -occlusionCulling 0\n            -shadingModel 0\n            -useBaseRenderer 0\n            -useReducedRenderer 0\n            -smallObjectCulling 0\n            -smallObjectThreshold -1 \n            -interactiveDisableShadows 0\n            -interactiveBackFaceCull 0\n            -sortTransparent 1\n            -controllers 1\n            -nurbsCurves 1\n            -nurbsSurfaces 1\n            -polymeshes 1\n            -subdivSurfaces 1\n            -planes 1\n            -lights 1\n            -cameras 1\n            -controlVertices 1\n"
		+ "            -hulls 1\n            -grid 1\n            -imagePlane 1\n            -joints 1\n            -ikHandles 1\n            -deformers 1\n            -dynamics 1\n            -particleInstancers 1\n            -fluids 1\n            -hairSystems 1\n            -follicles 1\n            -nCloths 1\n            -nParticles 1\n            -nRigids 1\n            -dynamicConstraints 1\n            -locators 1\n            -manipulators 1\n            -pluginShapes 1\n            -dimensions 1\n            -handles 1\n            -pivots 1\n            -textures 1\n            -strokes 1\n            -motionTrails 1\n            -clipGhosts 1\n            -greasePencils 1\n            -shadows 0\n            -captureSequenceNumber -1\n            -width 1\n            -height 1\n            -sceneRenderFilter 0\n            $editorName;\n        modelEditor -e -viewSelected 0 $editorName;\n        modelEditor -e \n            -pluginObjects \"gpuCacheDisplayFilter\" 1 \n            $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n"
		+ "\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextPanel \"modelPanel\" (localizedPanelLabel(\"Front View\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tmodelPanel -edit -l (localizedPanelLabel(\"Front View\")) -mbv $menusOkayInPanels  $panelName;\n\t\t$editorName = $panelName;\n        modelEditor -e \n            -camera \"front\" \n            -useInteractiveMode 0\n            -displayLights \"default\" \n            -displayAppearance \"smoothShaded\" \n            -activeOnly 0\n            -ignorePanZoom 0\n            -wireframeOnShaded 0\n            -headsUpDisplay 1\n            -holdOuts 1\n            -selectionHiliteDisplay 1\n            -useDefaultMaterial 0\n            -bufferMode \"double\" \n            -twoSidedLighting 0\n            -backfaceCulling 0\n            -xray 0\n            -jointXray 0\n            -activeComponentsXray 0\n            -displayTextures 0\n            -smoothWireframe 0\n            -lineWidth 1\n            -textureAnisotropic 0\n            -textureHilight 1\n            -textureSampling 2\n"
		+ "            -textureDisplay \"modulate\" \n            -textureMaxSize 16384\n            -fogging 0\n            -fogSource \"fragment\" \n            -fogMode \"linear\" \n            -fogStart 0\n            -fogEnd 100\n            -fogDensity 0.1\n            -fogColor 0.5 0.5 0.5 1 \n            -depthOfFieldPreview 1\n            -maxConstantTransparency 1\n            -rendererName \"vp2Renderer\" \n            -objectFilterShowInHUD 1\n            -isFiltered 0\n            -colorResolution 256 256 \n            -bumpResolution 512 512 \n            -textureCompression 0\n            -transparencyAlgorithm \"frontAndBackCull\" \n            -transpInShadows 0\n            -cullingOverride \"none\" \n            -lowQualityLighting 0\n            -maximumNumHardwareLights 1\n            -occlusionCulling 0\n            -shadingModel 0\n            -useBaseRenderer 0\n            -useReducedRenderer 0\n            -smallObjectCulling 0\n            -smallObjectThreshold -1 \n            -interactiveDisableShadows 0\n            -interactiveBackFaceCull 0\n"
		+ "            -sortTransparent 1\n            -controllers 1\n            -nurbsCurves 1\n            -nurbsSurfaces 1\n            -polymeshes 1\n            -subdivSurfaces 1\n            -planes 1\n            -lights 1\n            -cameras 1\n            -controlVertices 1\n            -hulls 1\n            -grid 1\n            -imagePlane 1\n            -joints 1\n            -ikHandles 1\n            -deformers 1\n            -dynamics 1\n            -particleInstancers 1\n            -fluids 1\n            -hairSystems 1\n            -follicles 1\n            -nCloths 1\n            -nParticles 1\n            -nRigids 1\n            -dynamicConstraints 1\n            -locators 1\n            -manipulators 1\n            -pluginShapes 1\n            -dimensions 1\n            -handles 1\n            -pivots 1\n            -textures 1\n            -strokes 1\n            -motionTrails 1\n            -clipGhosts 1\n            -greasePencils 1\n            -shadows 0\n            -captureSequenceNumber -1\n            -width 1\n            -height 1\n"
		+ "            -sceneRenderFilter 0\n            $editorName;\n        modelEditor -e -viewSelected 0 $editorName;\n        modelEditor -e \n            -pluginObjects \"gpuCacheDisplayFilter\" 1 \n            $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextPanel \"modelPanel\" (localizedPanelLabel(\"Persp View\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tmodelPanel -edit -l (localizedPanelLabel(\"Persp View\")) -mbv $menusOkayInPanels  $panelName;\n\t\t$editorName = $panelName;\n        modelEditor -e \n            -camera \"persp\" \n            -useInteractiveMode 0\n            -displayLights \"default\" \n            -displayAppearance \"wireframe\" \n            -activeOnly 0\n            -ignorePanZoom 0\n            -wireframeOnShaded 0\n            -headsUpDisplay 1\n            -holdOuts 1\n            -selectionHiliteDisplay 1\n            -useDefaultMaterial 0\n            -bufferMode \"double\" \n            -twoSidedLighting 0\n            -backfaceCulling 0\n"
		+ "            -xray 0\n            -jointXray 0\n            -activeComponentsXray 0\n            -displayTextures 0\n            -smoothWireframe 0\n            -lineWidth 1\n            -textureAnisotropic 0\n            -textureHilight 1\n            -textureSampling 2\n            -textureDisplay \"modulate\" \n            -textureMaxSize 16384\n            -fogging 0\n            -fogSource \"fragment\" \n            -fogMode \"linear\" \n            -fogStart 0\n            -fogEnd 100\n            -fogDensity 0.1\n            -fogColor 0.5 0.5 0.5 1 \n            -depthOfFieldPreview 1\n            -maxConstantTransparency 1\n            -rendererName \"vp2Renderer\" \n            -objectFilterShowInHUD 1\n            -isFiltered 0\n            -colorResolution 256 256 \n            -bumpResolution 512 512 \n            -textureCompression 0\n            -transparencyAlgorithm \"frontAndBackCull\" \n            -transpInShadows 0\n            -cullingOverride \"none\" \n            -lowQualityLighting 0\n            -maximumNumHardwareLights 1\n            -occlusionCulling 0\n"
		+ "            -shadingModel 0\n            -useBaseRenderer 0\n            -useReducedRenderer 0\n            -smallObjectCulling 0\n            -smallObjectThreshold -1 \n            -interactiveDisableShadows 0\n            -interactiveBackFaceCull 0\n            -sortTransparent 1\n            -controllers 1\n            -nurbsCurves 1\n            -nurbsSurfaces 1\n            -polymeshes 1\n            -subdivSurfaces 1\n            -planes 1\n            -lights 1\n            -cameras 1\n            -controlVertices 1\n            -hulls 1\n            -grid 1\n            -imagePlane 1\n            -joints 1\n            -ikHandles 1\n            -deformers 1\n            -dynamics 1\n            -particleInstancers 1\n            -fluids 1\n            -hairSystems 1\n            -follicles 1\n            -nCloths 1\n            -nParticles 1\n            -nRigids 1\n            -dynamicConstraints 1\n            -locators 1\n            -manipulators 1\n            -pluginShapes 1\n            -dimensions 1\n            -handles 1\n            -pivots 1\n"
		+ "            -textures 1\n            -strokes 1\n            -motionTrails 1\n            -clipGhosts 1\n            -greasePencils 1\n            -shadows 0\n            -captureSequenceNumber -1\n            -width 479\n            -height 723\n            -sceneRenderFilter 0\n            $editorName;\n        modelEditor -e -viewSelected 0 $editorName;\n        modelEditor -e \n            -pluginObjects \"gpuCacheDisplayFilter\" 1 \n            $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextPanel \"outlinerPanel\" (localizedPanelLabel(\"ToggledOutliner\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\toutlinerPanel -edit -l (localizedPanelLabel(\"ToggledOutliner\")) -mbv $menusOkayInPanels  $panelName;\n\t\t$editorName = $panelName;\n        outlinerEditor -e \n            -showShapes 1\n            -showAssignedMaterials 0\n            -showTimeEditor 1\n            -showReferenceNodes 1\n            -showReferenceMembers 1\n            -showAttributes 0\n"
		+ "            -showConnected 0\n            -showAnimCurvesOnly 0\n            -showMuteInfo 0\n            -organizeByLayer 1\n            -organizeByClip 1\n            -showAnimLayerWeight 1\n            -autoExpandLayers 1\n            -autoExpand 0\n            -showDagOnly 1\n            -showAssets 1\n            -showContainedOnly 1\n            -showPublishedAsConnected 0\n            -showParentContainers 0\n            -showContainerContents 1\n            -ignoreDagHierarchy 0\n            -expandConnections 0\n            -showUpstreamCurves 1\n            -showUnitlessCurves 1\n            -showCompounds 1\n            -showLeafs 1\n            -showNumericAttrsOnly 0\n            -highlightActive 1\n            -autoSelectNewObjects 0\n            -doNotSelectNewObjects 0\n            -dropIsParent 1\n            -transmitFilters 0\n            -setFilter \"defaultSetFilter\" \n            -showSetMembers 1\n            -allowMultiSelection 1\n            -alwaysToggleSelect 0\n            -directSelect 0\n            -isSet 0\n            -isSetMember 0\n"
		+ "            -displayMode \"DAG\" \n            -expandObjects 0\n            -setsIgnoreFilters 1\n            -containersIgnoreFilters 0\n            -editAttrName 0\n            -showAttrValues 0\n            -highlightSecondary 0\n            -showUVAttrsOnly 0\n            -showTextureNodesOnly 0\n            -attrAlphaOrder \"default\" \n            -animLayerFilterOptions \"allAffecting\" \n            -sortOrder \"none\" \n            -longNames 0\n            -niceNames 1\n            -showNamespace 1\n            -showPinIcons 0\n            -mapMotionTrails 0\n            -ignoreHiddenAttribute 0\n            -ignoreOutlinerColor 0\n            -renderFilterVisible 0\n            -renderFilterIndex 0\n            -selectionOrder \"chronological\" \n            -expandAttribute 0\n            $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextPanel \"outlinerPanel\" (localizedPanelLabel(\"Outliner\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n"
		+ "\t\toutlinerPanel -edit -l (localizedPanelLabel(\"Outliner\")) -mbv $menusOkayInPanels  $panelName;\n\t\t$editorName = $panelName;\n        outlinerEditor -e \n            -showShapes 0\n            -showAssignedMaterials 0\n            -showTimeEditor 1\n            -showReferenceNodes 0\n            -showReferenceMembers 0\n            -showAttributes 0\n            -showConnected 0\n            -showAnimCurvesOnly 0\n            -showMuteInfo 0\n            -organizeByLayer 1\n            -organizeByClip 1\n            -showAnimLayerWeight 1\n            -autoExpandLayers 1\n            -autoExpand 0\n            -showDagOnly 1\n            -showAssets 1\n            -showContainedOnly 1\n            -showPublishedAsConnected 0\n            -showParentContainers 0\n            -showContainerContents 1\n            -ignoreDagHierarchy 0\n            -expandConnections 0\n            -showUpstreamCurves 1\n            -showUnitlessCurves 1\n            -showCompounds 1\n            -showLeafs 1\n            -showNumericAttrsOnly 0\n            -highlightActive 1\n"
		+ "            -autoSelectNewObjects 0\n            -doNotSelectNewObjects 0\n            -dropIsParent 1\n            -transmitFilters 0\n            -setFilter \"defaultSetFilter\" \n            -showSetMembers 1\n            -allowMultiSelection 1\n            -alwaysToggleSelect 0\n            -directSelect 0\n            -isSet 0\n            -isSetMember 0\n            -displayMode \"DAG\" \n            -expandObjects 0\n            -setsIgnoreFilters 1\n            -containersIgnoreFilters 0\n            -editAttrName 0\n            -showAttrValues 0\n            -highlightSecondary 0\n            -showUVAttrsOnly 0\n            -showTextureNodesOnly 0\n            -attrAlphaOrder \"default\" \n            -animLayerFilterOptions \"allAffecting\" \n            -sortOrder \"none\" \n            -longNames 0\n            -niceNames 1\n            -showNamespace 1\n            -showPinIcons 0\n            -mapMotionTrails 0\n            -ignoreHiddenAttribute 0\n            -ignoreOutlinerColor 0\n            -renderFilterVisible 0\n            -renderFilterIndex 0\n"
		+ "            -selectionOrder \"chronological\" \n            -expandAttribute 0\n            $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"graphEditor\" (localizedPanelLabel(\"Graph Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Graph Editor\")) -mbv $menusOkayInPanels  $panelName;\n\n\t\t\t$editorName = ($panelName+\"OutlineEd\");\n            outlinerEditor -e \n                -showShapes 1\n                -showAssignedMaterials 0\n                -showTimeEditor 1\n                -showReferenceNodes 0\n                -showReferenceMembers 0\n                -showAttributes 1\n                -showConnected 1\n                -showAnimCurvesOnly 1\n                -showMuteInfo 0\n                -organizeByLayer 1\n                -organizeByClip 1\n                -showAnimLayerWeight 1\n                -autoExpandLayers 1\n                -autoExpand 1\n                -showDagOnly 0\n"
		+ "                -showAssets 1\n                -showContainedOnly 0\n                -showPublishedAsConnected 0\n                -showParentContainers 1\n                -showContainerContents 0\n                -ignoreDagHierarchy 0\n                -expandConnections 1\n                -showUpstreamCurves 1\n                -showUnitlessCurves 1\n                -showCompounds 0\n                -showLeafs 1\n                -showNumericAttrsOnly 1\n                -highlightActive 0\n                -autoSelectNewObjects 1\n                -doNotSelectNewObjects 0\n                -dropIsParent 1\n                -transmitFilters 1\n                -setFilter \"0\" \n                -showSetMembers 0\n                -allowMultiSelection 1\n                -alwaysToggleSelect 0\n                -directSelect 0\n                -displayMode \"DAG\" \n                -expandObjects 0\n                -setsIgnoreFilters 1\n                -containersIgnoreFilters 0\n                -editAttrName 0\n                -showAttrValues 0\n                -highlightSecondary 0\n"
		+ "                -showUVAttrsOnly 0\n                -showTextureNodesOnly 0\n                -attrAlphaOrder \"default\" \n                -animLayerFilterOptions \"allAffecting\" \n                -sortOrder \"none\" \n                -longNames 0\n                -niceNames 1\n                -showNamespace 1\n                -showPinIcons 1\n                -mapMotionTrails 1\n                -ignoreHiddenAttribute 0\n                -ignoreOutlinerColor 0\n                -renderFilterVisible 0\n                $editorName;\n\n\t\t\t$editorName = ($panelName+\"GraphEd\");\n            animCurveEditor -e \n                -displayKeys 1\n                -displayTangents 0\n                -displayActiveKeys 0\n                -displayActiveKeyTangents 1\n                -displayInfinities 0\n                -displayValues 0\n                -autoFit 1\n                -snapTime \"integer\" \n                -snapValue \"none\" \n                -showResults \"off\" \n                -showBufferCurves \"off\" \n                -smoothness \"fine\" \n                -resultSamples 1\n"
		+ "                -resultScreenSamples 0\n                -resultUpdate \"delayed\" \n                -showUpstreamCurves 1\n                -showCurveNames 0\n                -showActiveCurveNames 0\n                -stackedCurves 0\n                -stackedCurvesMin -1\n                -stackedCurvesMax 1\n                -stackedCurvesSpace 0.2\n                -displayNormalized 0\n                -preSelectionHighlight 0\n                -constrainDrag 0\n                -classicMode 1\n                -valueLinesToggle 1\n                $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"dopeSheetPanel\" (localizedPanelLabel(\"Dope Sheet\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Dope Sheet\")) -mbv $menusOkayInPanels  $panelName;\n\n\t\t\t$editorName = ($panelName+\"OutlineEd\");\n            outlinerEditor -e \n                -showShapes 1\n                -showAssignedMaterials 0\n"
		+ "                -showTimeEditor 1\n                -showReferenceNodes 0\n                -showReferenceMembers 0\n                -showAttributes 1\n                -showConnected 1\n                -showAnimCurvesOnly 1\n                -showMuteInfo 0\n                -organizeByLayer 1\n                -organizeByClip 1\n                -showAnimLayerWeight 1\n                -autoExpandLayers 1\n                -autoExpand 0\n                -showDagOnly 0\n                -showAssets 1\n                -showContainedOnly 0\n                -showPublishedAsConnected 0\n                -showParentContainers 1\n                -showContainerContents 0\n                -ignoreDagHierarchy 0\n                -expandConnections 1\n                -showUpstreamCurves 1\n                -showUnitlessCurves 0\n                -showCompounds 1\n                -showLeafs 1\n                -showNumericAttrsOnly 1\n                -highlightActive 0\n                -autoSelectNewObjects 0\n                -doNotSelectNewObjects 1\n                -dropIsParent 1\n"
		+ "                -transmitFilters 0\n                -setFilter \"0\" \n                -showSetMembers 0\n                -allowMultiSelection 1\n                -alwaysToggleSelect 0\n                -directSelect 0\n                -displayMode \"DAG\" \n                -expandObjects 0\n                -setsIgnoreFilters 1\n                -containersIgnoreFilters 0\n                -editAttrName 0\n                -showAttrValues 0\n                -highlightSecondary 0\n                -showUVAttrsOnly 0\n                -showTextureNodesOnly 0\n                -attrAlphaOrder \"default\" \n                -animLayerFilterOptions \"allAffecting\" \n                -sortOrder \"none\" \n                -longNames 0\n                -niceNames 1\n                -showNamespace 1\n                -showPinIcons 0\n                -mapMotionTrails 1\n                -ignoreHiddenAttribute 0\n                -ignoreOutlinerColor 0\n                -renderFilterVisible 0\n                $editorName;\n\n\t\t\t$editorName = ($panelName+\"DopeSheetEd\");\n            dopeSheetEditor -e \n"
		+ "                -displayKeys 1\n                -displayTangents 0\n                -displayActiveKeys 0\n                -displayActiveKeyTangents 0\n                -displayInfinities 0\n                -displayValues 0\n                -autoFit 0\n                -snapTime \"integer\" \n                -snapValue \"none\" \n                -outliner \"dopeSheetPanel1OutlineEd\" \n                -showSummary 1\n                -showScene 0\n                -hierarchyBelow 0\n                -showTicks 1\n                -selectionWindow 0 0 0 0 \n                $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"timeEditorPanel\" (localizedPanelLabel(\"Time Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Time Editor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"clipEditorPanel\" (localizedPanelLabel(\"Trax Editor\")) `;\n"
		+ "\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Trax Editor\")) -mbv $menusOkayInPanels  $panelName;\n\n\t\t\t$editorName = clipEditorNameFromPanel($panelName);\n            clipEditor -e \n                -displayKeys 0\n                -displayTangents 0\n                -displayActiveKeys 0\n                -displayActiveKeyTangents 0\n                -displayInfinities 0\n                -displayValues 0\n                -autoFit 0\n                -snapTime \"none\" \n                -snapValue \"none\" \n                -initialized 0\n                -manageSequencer 0 \n                $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"sequenceEditorPanel\" (localizedPanelLabel(\"Camera Sequencer\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Camera Sequencer\")) -mbv $menusOkayInPanels  $panelName;\n\n\t\t\t$editorName = sequenceEditorNameFromPanel($panelName);\n"
		+ "            clipEditor -e \n                -displayKeys 0\n                -displayTangents 0\n                -displayActiveKeys 0\n                -displayActiveKeyTangents 0\n                -displayInfinities 0\n                -displayValues 0\n                -autoFit 0\n                -snapTime \"none\" \n                -snapValue \"none\" \n                -initialized 0\n                -manageSequencer 1 \n                $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"hyperGraphPanel\" (localizedPanelLabel(\"Hypergraph Hierarchy\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Hypergraph Hierarchy\")) -mbv $menusOkayInPanels  $panelName;\n\n\t\t\t$editorName = ($panelName+\"HyperGraphEd\");\n            hyperGraph -e \n                -graphLayoutStyle \"hierarchicalLayout\" \n                -orientation \"horiz\" \n                -mergeConnections 0\n                -zoom 1\n"
		+ "                -animateTransition 0\n                -showRelationships 1\n                -showShapes 0\n                -showDeformers 0\n                -showExpressions 0\n                -showConstraints 0\n                -showConnectionFromSelected 0\n                -showConnectionToSelected 0\n                -showConstraintLabels 0\n                -showUnderworld 0\n                -showInvisible 0\n                -transitionFrames 1\n                -opaqueContainers 0\n                -freeform 0\n                -imagePosition 0 0 \n                -imageScale 1\n                -imageEnabled 0\n                -graphType \"DAG\" \n                -heatMapDisplay 0\n                -updateSelection 1\n                -updateNodeAdded 1\n                -useDrawOverrideColor 0\n                -limitGraphTraversal -1\n                -range 0 0 \n                -iconSize \"smallIcons\" \n                -showCachedConnections 0\n                $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n"
		+ "\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"hyperShadePanel\" (localizedPanelLabel(\"Hypershade\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Hypershade\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"visorPanel\" (localizedPanelLabel(\"Visor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Visor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"createNodePanel\" (localizedPanelLabel(\"Create Node\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Create Node\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n"
		+ "\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"polyTexturePlacementPanel\" (localizedPanelLabel(\"UV Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"UV Editor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"renderWindowPanel\" (localizedPanelLabel(\"Render View\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Render View\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextPanel \"shapePanel\" (localizedPanelLabel(\"Shape Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tshapePanel -edit -l (localizedPanelLabel(\"Shape Editor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n"
		+ "\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextPanel \"posePanel\" (localizedPanelLabel(\"Pose Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tposePanel -edit -l (localizedPanelLabel(\"Pose Editor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"dynRelEdPanel\" (localizedPanelLabel(\"Dynamic Relationships\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Dynamic Relationships\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"relationshipPanel\" (localizedPanelLabel(\"Relationship Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Relationship Editor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n"
		+ "\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"referenceEditorPanel\" (localizedPanelLabel(\"Reference Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Reference Editor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"componentEditorPanel\" (localizedPanelLabel(\"Component Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Component Editor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"dynPaintScriptedPanelType\" (localizedPanelLabel(\"Paint Effects\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Paint Effects\")) -mbv $menusOkayInPanels  $panelName;\n"
		+ "\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"scriptEditorPanel\" (localizedPanelLabel(\"Script Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Script Editor\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"profilerPanel\" (localizedPanelLabel(\"Profiler Tool\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Profiler Tool\")) -mbv $menusOkayInPanels  $panelName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"contentBrowserPanel\" (localizedPanelLabel(\"Content Browser\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Content Browser\")) -mbv $menusOkayInPanels  $panelName;\n"
		+ "\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\t$panelName = `sceneUIReplacement -getNextScriptedPanel \"nodeEditorPanel\" (localizedPanelLabel(\"Node Editor\")) `;\n\tif (\"\" != $panelName) {\n\t\t$label = `panel -q -label $panelName`;\n\t\tscriptedPanel -edit -l (localizedPanelLabel(\"Node Editor\")) -mbv $menusOkayInPanels  $panelName;\n\n\t\t\t$editorName = ($panelName+\"NodeEditorEd\");\n            nodeEditor -e \n                -allAttributes 0\n                -allNodes 0\n                -autoSizeNodes 1\n                -consistentNameSize 1\n                -createNodeCommand \"nodeEdCreateNodeCommand\" \n                -connectNodeOnCreation 0\n                -connectOnDrop 0\n                -highlightConnections 0\n                -copyConnectionsOnPaste 0\n                -defaultPinnedState 0\n                -additiveGraphingMode 0\n                -settingsChangedCallback \"nodeEdSyncControls\" \n                -traversalDepthLimit -1\n                -keyPressCommand \"nodeEdKeyPressCommand\" \n                -nodeTitleMode \"name\" \n"
		+ "                -gridSnap 0\n                -gridVisibility 1\n                -crosshairOnEdgeDragging 0\n                -popupMenuScript \"nodeEdBuildPanelMenus\" \n                -showNamespace 1\n                -showShapes 1\n                -showSGShapes 0\n                -showTransforms 1\n                -useAssets 1\n                -syncedSelection 1\n                -extendToShapes 1\n                -activeTab -1\n                -editorMode \"default\" \n                $editorName;\n\t\tif (!$useSceneConfig) {\n\t\t\tpanel -e -l $label $panelName;\n\t\t}\n\t}\n\n\n\tif ($useSceneConfig) {\n        string $configName = `getPanel -cwl (localizedPanelLabel(\"Current Layout\"))`;\n        if (\"\" != $configName) {\n\t\t\tpanelConfiguration -edit -label (localizedPanelLabel(\"Current Layout\")) \n\t\t\t\t-userCreated false\n\t\t\t\t-defaultImage \"\"\n\t\t\t\t-image \"\"\n\t\t\t\t-sc false\n\t\t\t\t-configString \"global string $gMainPane; paneLayout -e -cn \\\"single\\\" -ps 1 100 100 $gMainPane;\"\n\t\t\t\t-removeAllPanels\n\t\t\t\t-ap false\n\t\t\t\t\t(localizedPanelLabel(\"Persp View\")) \n"
		+ "\t\t\t\t\t\"modelPanel\"\n"
		+ "\t\t\t\t\t\"$panelName = `modelPanel -unParent -l (localizedPanelLabel(\\\"Persp View\\\")) -mbv $menusOkayInPanels `;\\n$editorName = $panelName;\\nmodelEditor -e \\n    -cam `findStartUpCamera persp` \\n    -useInteractiveMode 0\\n    -displayLights \\\"default\\\" \\n    -displayAppearance \\\"wireframe\\\" \\n    -activeOnly 0\\n    -ignorePanZoom 0\\n    -wireframeOnShaded 0\\n    -headsUpDisplay 1\\n    -holdOuts 1\\n    -selectionHiliteDisplay 1\\n    -useDefaultMaterial 0\\n    -bufferMode \\\"double\\\" \\n    -twoSidedLighting 0\\n    -backfaceCulling 0\\n    -xray 0\\n    -jointXray 0\\n    -activeComponentsXray 0\\n    -displayTextures 0\\n    -smoothWireframe 0\\n    -lineWidth 1\\n    -textureAnisotropic 0\\n    -textureHilight 1\\n    -textureSampling 2\\n    -textureDisplay \\\"modulate\\\" \\n    -textureMaxSize 16384\\n    -fogging 0\\n    -fogSource \\\"fragment\\\" \\n    -fogMode \\\"linear\\\" \\n    -fogStart 0\\n    -fogEnd 100\\n    -fogDensity 0.1\\n    -fogColor 0.5 0.5 0.5 1 \\n    -depthOfFieldPreview 1\\n    -maxConstantTransparency 1\\n    -rendererName \\\"vp2Renderer\\\" \\n    -objectFilterShowInHUD 1\\n    -isFiltered 0\\n    -colorResolution 256 256 \\n    -bumpResolution 512 512 \\n    -textureCompression 0\\n    -transparencyAlgorithm \\\"frontAndBackCull\\\" \\n    -transpInShadows 0\\n    -cullingOverride \\\"none\\\" \\n    -lowQualityLighting 0\\n    -maximumNumHardwareLights 1\\n    -occlusionCulling 0\\n    -shadingModel 0\\n    -useBaseRenderer 0\\n    -useReducedRenderer 0\\n    -smallObjectCulling 0\\n    -smallObjectThreshold -1 \\n    -interactiveDisableShadows 0\\n    -interactiveBackFaceCull 0\\n    -sortTransparent 1\\n    -controllers 1\\n    -nurbsCurves 1\\n    -nurbsSurfaces 1\\n    -polymeshes 1\\n    -subdivSurfaces 1\\n    -planes 1\\n    -lights 1\\n    -cameras 1\\n    -controlVertices 1\\n    -hulls 1\\n    -grid 1\\n    -imagePlane 1\\n    -joints 1\\n    -ikHandles 1\\n    -deformers 1\\n    -dynamics 1\\n    -particleInstancers 1\\n    -fluids 1\\n    -hairSystems 1\\n    -follicles 1\\n    -nCloths 1\\n    -nParticles 1\\n    -nRigids 1\\n    -dynamicConstraints 1\\n    -locators 1\\n    -manipulators 1\\n    -pluginShapes 1\\n    -dimensions 1\\n    -handles 1\\n    -pivots 1\\n    -textures 1\\n    -strokes 1\\n    -motionTrails 1\\n    -clipGhosts 1\\n    -greasePencils 1\\n    -shadows 0\\n    -captureSequenceNumber -1\\n    -width 479\\n    -height 723\\n    -sceneRenderFilter 0\\n    $editorName;\\nmodelEditor -e -viewSelected 0 $editorName;\\nmodelEditor -e \\n    -pluginObjects \\\"gpuCacheDisplayFilter\\\" 1 \\n    $editorName\"\n"
		+ "\t\t\t\t\t\"modelPanel -edit -l (localizedPanelLabel(\\\"Persp View\\\")) -mbv $menusOkayInPanels  $panelName;\\n$editorName = $panelName;\\nmodelEditor -e \\n    -cam `findStartUpCamera persp` \\n    -useInteractiveMode 0\\n    -displayLights \\\"default\\\" \\n    -displayAppearance \\\"wireframe\\\" \\n    -activeOnly 0\\n    -ignorePanZoom 0\\n    -wireframeOnShaded 0\\n    -headsUpDisplay 1\\n    -holdOuts 1\\n    -selectionHiliteDisplay 1\\n    -useDefaultMaterial 0\\n    -bufferMode \\\"double\\\" \\n    -twoSidedLighting 0\\n    -backfaceCulling 0\\n    -xray 0\\n    -jointXray 0\\n    -activeComponentsXray 0\\n    -displayTextures 0\\n    -smoothWireframe 0\\n    -lineWidth 1\\n    -textureAnisotropic 0\\n    -textureHilight 1\\n    -textureSampling 2\\n    -textureDisplay \\\"modulate\\\" \\n    -textureMaxSize 16384\\n    -fogging 0\\n    -fogSource \\\"fragment\\\" \\n    -fogMode \\\"linear\\\" \\n    -fogStart 0\\n    -fogEnd 100\\n    -fogDensity 0.1\\n    -fogColor 0.5 0.5 0.5 1 \\n    -depthOfFieldPreview 1\\n    -maxConstantTransparency 1\\n    -rendererName \\\"vp2Renderer\\\" \\n    -objectFilterShowInHUD 1\\n    -isFiltered 0\\n    -colorResolution 256 256 \\n    -bumpResolution 512 512 \\n    -textureCompression 0\\n    -transparencyAlgorithm \\\"frontAndBackCull\\\" \\n    -transpInShadows 0\\n    -cullingOverride \\\"none\\\" \\n    -lowQualityLighting 0\\n    -maximumNumHardwareLights 1\\n    -occlusionCulling 0\\n    -shadingModel 0\\n    -useBaseRenderer 0\\n    -useReducedRenderer 0\\n    -smallObjectCulling 0\\n    -smallObjectThreshold -1 \\n    -interactiveDisableShadows 0\\n    -interactiveBackFaceCull 0\\n    -sortTransparent 1\\n    -controllers 1\\n    -nurbsCurves 1\\n    -nurbsSurfaces 1\\n    -polymeshes 1\\n    -subdivSurfaces 1\\n    -planes 1\\n    -lights 1\\n    -cameras 1\\n    -controlVertices 1\\n    -hulls 1\\n    -grid 1\\n    -imagePlane 1\\n    -joints 1\\n    -ikHandles 1\\n    -deformers 1\\n    -dynamics 1\\n    -particleInstancers 1\\n    -fluids 1\\n    -hairSystems 1\\n    -follicles 1\\n    -nCloths 1\\n    -nParticles 1\\n    -nRigids 1\\n    -dynamicConstraints 1\\n    -locators 1\\n    -manipulators 1\\n    -pluginShapes 1\\n    -dimensions 1\\n    -handles 1\\n    -pivots 1\\n    -textures 1\\n    -strokes 1\\n    -motionTrails 1\\n    -clipGhosts 1\\n    -greasePencils 1\\n    -shadows 0\\n    -captureSequenceNumber -1\\n    -width 479\\n    -height 723\\n    -sceneRenderFilter 0\\n    $editorName;\\nmodelEditor -e -viewSelected 0 $editorName;\\nmodelEditor -e \\n    -pluginObjects \\\"gpuCacheDisplayFilter\\\" 1 \\n    $editorName\"\n"
		+ "\t\t\t\t$configName;\n\n            setNamedPanelLayout (localizedPanelLabel(\"Current Layout\"));\n        }\n\n        panelHistory -e -clear mainPanelHistory;\n        sceneUIReplacement -clear;\n\t}\n\n\ngrid -spacing 5 -size 12 -divisions 5 -displayAxes yes -displayGridLines yes -displayDivisionLines yes -displayPerspectiveLabels no -displayOrthographicLabels no -displayAxesBold yes -perspectiveLabelPosition axis -orthographicLabelPosition edge;\nviewManip -drawCompass 0 -compassAngle 0 -frontParameters \"\" -homeParameters \"\" -selectionLockParameters \"\";\n}\n");
	setAttr ".st" 3;
createNode script -n "sceneConfigurationScriptNode";
	rename -uid "E7CC086F-4586-E387-5D61-85939D7A05C8";
	setAttr ".b" -type "string" "playbackOptions -min 1 -max 120 -ast 1 -aet 200 ";
	setAttr ".st" 6;
createNode skinCluster -n "skinCluster1";
	rename -uid "589B2440-425A-769D-147E-C99D0983ED90";
	setAttr -s 132 ".wl";
	setAttr ".wl[0:131].w"
		3 0 0.8803543578623203 1 0.097817150873591649 2 0.021828491264088087
		3 0 0.89281006174838995 1 0.088687592774019594 2 0.018502345477590446
		3 0 0.90399145712505358 1 0.080410443554675956 2 0.015598099320270491
		3 0 0.91337688669409878 1 0.073452674559272013 2 0.0131704387466293
		3 0 0.92027635586247292 1 0.068450307460845669 2 0.011273336676681463
		3 0 0.92370152323947319 1 0.066330994940645427 2 0.0099674818198814824
		3 0 0.92207595165089717 1 0.068584161693042725 2 0.0093398866560601077
		3 0 0.91262355806741013 1 0.077832802469686158 2 0.0095436394629037254
		3 0 0.89022495664071211 1 0.098913884071191741 2 0.01086115928809623
		3 0 0.85369935550358 1 0.13324007621333289 2 0.013060568283087144
		3 0 0.8058942284554379 1 0.17846792602473546 2 0.01563784551982669
		3 0 0.74621863599796978 1 0.23518863750751856 2 0.018592726494511602
		3 0 0.67711189428996321 1 0.30093861968443031 2 0.021949486025606379
		3 0 0.60535348711031745 1 0.36875786484293277 2 0.025888648046749674
		3 0 0.54131026000641358 1 0.42770193383223054 2 0.03098780616135596
		3 0 0.49552107941547563 1 0.46594452279288273 2 0.038534397791641702
		3 0 0.47457404456913382 1 0.47457404456913371 2 0.050851910861732484
		3 0 0.45274415100642385 1 0.47527667620692554 2 0.071979172786650628
		3 0 0.40023650881448314 1 0.49320339003783992 2 0.10656010114767697
		3 0 0.32645911370762692 1 0.51468317502103234 2 0.15885771127134077
		3 0 0.24623734937572159 1 0.52483135814004889 2 0.22893129248422953
		3 0 0.1742361498118237 1 0.51654995335252984 2 0.30921389683564648
		3 0 0.11905935871564301 1 0.49550496383246007 2 0.385435677451897
		3 0 0.081681582783211068 1 0.47577836859529687 2 0.44254004862149204
		3 0 0.058360572643809255 1 0.47099706566777472 2 0.470642361688416
		3 0 0.045302436649367582 1 0.47734878167531625 2 0.47734878167531625
		3 0 0.039421987365194776 1 0.48028900631740268 2 0.48028900631740257
		3 0 0.037693280479834057 1 0.48115335976008294 2 0.48115335976008294
		3 0 0.038534615315674342 1 0.48073269234216282 2 0.48073269234216282
		3 0 0.041080806459683275 1 0.47945959677015831 2 0.47945959677015831
		3 0 0.044814215954946689 1 0.47759289202252664 2 0.47759289202252664
		3 0 0.049392886148733939 1 0.47530355692563309 2 0.47530355692563298
		3 0 0.054571676460235349 1 0.47271416176988235 2 0.47271416176988235
		3 0 0.8803543578623203 1 0.097817150873591649 2 0.021828491264088087
		3 0 0.89281006174838995 1 0.088687592774019594 2 0.018502345477590446
		3 0 0.90399145712505358 1 0.080410443554675956 2 0.015598099320270491
		3 0 0.91337688669409878 1 0.073452674559272013 2 0.0131704387466293
		3 0 0.92027635586247292 1 0.068450307460845669 2 0.011273336676681463
		3 0 0.92370152323947319 1 0.066330994940645427 2 0.0099674818198814824
		3 0 0.92207595165089717 1 0.068584161693042725 2 0.0093398866560601077
		3 0 0.91262355806741013 1 0.077832802469686158 2 0.0095436394629037254
		3 0 0.89022495664071211 1 0.098913884071191741 2 0.01086115928809623
		3 0 0.85369935550358 1 0.13324007621333289 2 0.013060568283087144
		3 0 0.8058942284554379 1 0.17846792602473546 2 0.01563784551982669
		3 0 0.74621863599796978 1 0.23518863750751856 2 0.018592726494511602
		3 0 0.67711189428996321 1 0.30093861968443031 2 0.021949486025606379
		3 0 0.60535348711031745 1 0.36875786484293277 2 0.025888648046749674
		3 0 0.54131026000641358 1 0.42770193383223054 2 0.03098780616135596
		3 0 0.49552107941547563 1 0.46594452279288273 2 0.038534397791641702
		3 0 0.47457404456913382 1 0.47457404456913371 2 0.050851910861732484
		3 0 0.45274415100642385 1 0.47527667620692554 2 0.071979172786650628
		3 0 0.40023650881448314 1 0.49320339003783992 2 0.10656010114767697
		3 0 0.32645911370762692 1 0.51468317502103234 2 0.15885771127134077
		3 0 0.24623734937572159 1 0.52483135814004889 2 0.22893129248422953
		3 0 0.1742361498118237 1 0.51654995335252984 2 0.30921389683564648
		3 0 0.11905935871564301 1 0.49550496383246007 2 0.385435677451897
		3 0 0.081681582783211068 1 0.47577836859529687 2 0.44254004862149204
		3 0 0.058360572643809255 1 0.47099706566777472 2 0.470642361688416
		3 0 0.045302436649367582 1 0.47734878167531625 2 0.47734878167531625
		3 0 0.039421987365194776 1 0.48028900631740268 2 0.48028900631740257
		3 0 0.037693280479834057 1 0.48115335976008294 2 0.48115335976008294
		3 0 0.038534615315674342 1 0.48073269234216282 2 0.48073269234216282
		3 0 0.041080806459683275 1 0.47945959677015831 2 0.47945959677015831
		3 0 0.044814215954946689 1 0.47759289202252664 2 0.47759289202252664
		3 0 0.049392886148733939 1 0.47530355692563309 2 0.47530355692563298
		3 0 0.054571676460235349 1 0.47271416176988235 2 0.47271416176988235
		3 0 0.88013094495883981 1 0.097792327217648287 2 0.022076727823511989
		3 0 0.89260181674173822 1 0.088666906685074875 2 0.018731276573186878
		3 0 0.90379808876576595 1 0.080393243352817653 2 0.015808667881416487
		3 0 0.91319680634583322 1 0.07343819271348706 2 0.013365000940679668
		3 0 0.92010618791013254 1 0.068437650340422498 2 0.011456161749445047
		3 0 0.92353538475434738 1 0.066319064538085476 2 0.010145550707567237
		3 0 0.92190423710610858 1 0.068571389536817226 2 0.0095243733570743276
		3 0 0.91243075745983315 1 0.077816359532754772 2 0.0097528830074120037
		3 0 0.88998611294632024 1 0.098887345882923056 2 0.011126541170756793
		3 0 0.85339027931426681 1 0.13319183752748029 2 0.013417883158252873
		3 0 0.80549981205260213 1 0.17838058121579928 2 0.016119606731598624
		3 0 0.74572514844420146 1 0.23503310311075878 2 0.019241748445039793
		3 0 0.67650680784446626 1 0.30066969237531627 2 0.02282349978021752
		3 0 0.60461754815235846 1 0.36830955937418858 2 0.027072892473452809
		3 0 0.5403943224479999 1 0.42697823008236746 2 0.032627447469632635
		3 0 0.49429856674363554 1 0.46479497919695167 2 0.040906454059412914
		3 0 0.47257926594427269 1 0.47293568064429276 2 0.054485053411434496
		3 0 0.44397367551264288 1 0.47904270531201021 2 0.076983619175346948
		3 0 0.38504946106089338 1 0.50127035722470226 2 0.11368018171440453
		3 0 0.30652578708340461 1 0.52474222470357412 2 0.16873198821302124
		3 0 0.22446227475908248 1 0.5339455998230167 2 0.2415921254179009
		3 0 0.15367396306270709 1 0.52261261296112504 2 0.32371342397616787
		3 0 0.10160528832059598 1 0.49856436437196883 2 0.39983034730743522
		3 0 0.067741989802821492 1 0.47815696196875163 2 0.4541010482284269
		3 0 0.047419878649532773 1 0.47629006067523361 2 0.47629006067523361
		3 0 0.036938352574473768 1 0.48153082371276296 2 0.48153082371276318
		3 0 0.032663970278840347 1 0.48366801486057981 2 0.48366801486057981
		3 0 0.031950237931985717 1 0.48402488103400715 2 0.48402488103400715
		3 0 0.033466476818311601 1 0.48326676159084425 2 0.48326676159084425
		3 0 0.036493645552549324 1 0.48175317722372535 2 0.48175317722372535
		3 0 0.040596327961543298 1 0.47970183601922833 2 0.47970183601922833
		3 0 0.045478008267243242 1 0.47726099586637821 2 0.47726099586637843
		3 0 0.050918401053031116 1 0.47454079947348443 2 0.47454079947348443
		3 0 0.88013094495883981 1 0.097792327217648287 2 0.022076727823511989
		3 0 0.89260181674173822 1 0.088666906685074875 2 0.018731276573186878
		3 0 0.90379808876576595 1 0.080393243352817653 2 0.015808667881416487
		3 0 0.91319680634583322 1 0.07343819271348706 2 0.013365000940679668
		3 0 0.92010618791013254 1 0.068437650340422498 2 0.011456161749445047
		3 0 0.92353538475434738 1 0.066319064538085476 2 0.010145550707567237
		3 0 0.92190423710610858 1 0.068571389536817226 2 0.0095243733570743276
		3 0 0.91243075745983315 1 0.077816359532754772 2 0.0097528830074120037
		3 0 0.88998611294632024 1 0.098887345882923056 2 0.011126541170756793
		3 0 0.85339027931426681 1 0.13319183752748029 2 0.013417883158252873
		3 0 0.80549981205260213 1 0.17838058121579928 2 0.016119606731598624
		3 0 0.74572514844420146 1 0.23503310311075878 2 0.019241748445039793
		3 0 0.67650680784446626 1 0.30066969237531627 2 0.02282349978021752
		3 0 0.60461754815235846 1 0.36830955937418858 2 0.027072892473452809
		3 0 0.5403943224479999 1 0.42697823008236746 2 0.032627447469632635
		3 0 0.49429856674363554 1 0.46479497919695167 2 0.040906454059412914
		3 0 0.47257926594427269 1 0.47293568064429276 2 0.054485053411434496
		3 0 0.44397367551264288 1 0.47904270531201021 2 0.076983619175346948
		3 0 0.38504946106089338 1 0.50127035722470226 2 0.11368018171440453
		3 0 0.30652578708340461 1 0.52474222470357412 2 0.16873198821302124
		3 0 0.22446227475908248 1 0.5339455998230167 2 0.2415921254179009
		3 0 0.15367396306270709 1 0.52261261296112504 2 0.32371342397616787
		3 0 0.10160528832059598 1 0.49856436437196883 2 0.39983034730743522
		3 0 0.067741989802821492 1 0.47815696196875163 2 0.4541010482284269
		3 0 0.047419878649532773 1 0.47629006067523361 2 0.47629006067523361
		3 0 0.036938352574473768 1 0.48153082371276296 2 0.48153082371276318
		3 0 0.032663970278840347 1 0.48366801486057981 2 0.48366801486057981
		3 0 0.031950237931985717 1 0.48402488103400715 2 0.48402488103400715
		3 0 0.033466476818311601 1 0.48326676159084425 2 0.48326676159084425
		3 0 0.036493645552549324 1 0.48175317722372535 2 0.48175317722372535
		3 0 0.040596327961543298 1 0.47970183601922833 2 0.47970183601922833
		3 0 0.045478008267243242 1 0.47726099586637821 2 0.47726099586637843
		3 0 0.050918401053031116 1 0.47454079947348443 2 0.47454079947348443;
	setAttr -s 3 ".pm";
	setAttr ".pm[0]" -type "matrix" 1 -0 0 -0 -0 1 -0 0 0 -0 1 -0 1 0 -0 1;
	setAttr ".pm[1]" -type "matrix" 0.99962304696860638 -0 0.027454762231703449 -0 -0 1 -0 0
		 -0.027454762231703449 -0 0.99962304696860638 -0 3.1014325075638129e-16 0 -1.1292261018375849e-14 1;
	setAttr ".pm[2]" -type "matrix" 0.99962304696860638 -0 0.027454762231703449 -0 -0 1 -0 0
		 -0.027454762231703449 -0 0.99962304696860638 -0 -0.99999999999999967 0 -1.503311364281501e-14 1;
	setAttr ".gm" -type "matrix" 1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1;
	setAttr -s 3 ".ma";
	setAttr -s 3 ".dpf[0:2]"  4 4 4;
	setAttr -s 3 ".lw";
	setAttr -s 3 ".lw";
	setAttr ".mmi" yes;
	setAttr ".mi" 4;
	setAttr ".ucm" yes;
	setAttr -s 3 ".ifcl";
	setAttr -s 3 ".ifcl";
createNode tweak -n "tweak1";
	rename -uid "2B99B85B-4A92-1E3E-E0D5-D9832FE8EB18";
createNode objectSet -n "skinCluster1Set";
	rename -uid "5CE5A94D-47A6-84BA-7D9A-F694664A4119";
	setAttr ".ihi" 0;
	setAttr ".vo" yes;
createNode groupId -n "skinCluster1GroupId";
	rename -uid "E3A8643A-45B5-AB9D-7FBC-D0873940BFA6";
	setAttr ".ihi" 0;
createNode groupParts -n "skinCluster1GroupParts";
	rename -uid "5ECEC6CA-4AA1-F182-C813-52866CDFE0A0";
	setAttr ".ihi" 0;
	setAttr ".ic" -type "componentList" 1 "vtx[*]";
createNode objectSet -n "tweakSet1";
	rename -uid "DF0A26B6-42F2-5B1D-D53D-008FB4CB0B3B";
	setAttr ".ihi" 0;
	setAttr ".vo" yes;
createNode groupId -n "groupId2";
	rename -uid "B88FE42C-4BC5-9E13-D952-9E8BF4CFB1F9";
	setAttr ".ihi" 0;
createNode groupParts -n "groupParts2";
	rename -uid "A71016C9-48DE-FAA8-25EC-98AD97345A76";
	setAttr ".ihi" 0;
	setAttr ".ic" -type "componentList" 1 "vtx[*]";
createNode dagPose -n "bindPose2";
	rename -uid "C305AED5-4956-3F2C-1FED-6EAFD40BCEFA";
	setAttr -s 3 ".wm";
	setAttr -s 3 ".xm";
	setAttr ".xm[0]" -type "matrix" "xform" 1 1 1 0 0 0 0 -1 0 0 0 0 0 0 0 0 0 0
		 0 0 0 0 0 0 0 0 0 0 1 0 0 0 1 1 1 1 yes;
	setAttr ".xm[1]" -type "matrix" "xform" 1 1 1 0 0 0 0 1 0 1.1296519275560968e-14 0
		 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0.013728674943227832 0 0.99990575730130848 1
		 1 1 yes;
	setAttr ".xm[2]" -type "matrix" "xform" 1 1 1 0 0 0 0 1 0 3.7400638142059961e-15 0
		 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 1 1 1 1 yes;
	setAttr -s 3 ".m";
	setAttr -s 3 ".p";
	setAttr ".bp" yes;
select -ne :time1;
	setAttr ".o" 1;
	setAttr ".unw" 1;
select -ne :hardwareRenderingGlobals;
	setAttr ".otfna" -type "stringArray" 22 "NURBS Curves" "NURBS Surfaces" "Polygons" "Subdiv Surface" "Particles" "Particle Instance" "Fluids" "Strokes" "Image Planes" "UI" "Lights" "Cameras" "Locators" "Joints" "IK Handles" "Deformers" "Motion Trails" "Components" "Hair Systems" "Follicles" "Misc. UI" "Ornaments"  ;
	setAttr ".otfva" -type "Int32Array" 22 0 1 1 1 1 1
		 1 1 1 0 0 0 0 0 0 0 0 0
		 0 0 0 0 ;
	setAttr ".fprt" yes;
select -ne :renderPartition;
	setAttr -s 2 ".st";
select -ne :renderGlobalsList1;
select -ne :defaultShaderList1;
	setAttr -s 4 ".s";
select -ne :postProcessList1;
	setAttr -s 2 ".p";
select -ne :defaultRenderingList1;
select -ne :initialShadingGroup;
	setAttr ".ro" yes;
select -ne :initialParticleSE;
	setAttr ".ro" yes;
select -ne :defaultResolution;
	setAttr ".pa" 1;
select -ne :hardwareRenderGlobals;
	setAttr ".ctrs" 256;
	setAttr ".btrs" 512;
select -ne :ikSystem;
	setAttr -s 4 ".sol";
connectAttr "joint1.s" "joint2.is";
connectAttr "pasted__joint2_rotateX.o" "joint2.rx";
connectAttr "pasted__joint2_rotateY.o" "joint2.ry";
connectAttr "pasted__joint2_rotateZ.o" "joint2.rz";
connectAttr "joint2.s" "joint3.is";
connectAttr "skinCluster1GroupId.id" "pCubeShape1.iog.og[4].gid";
connectAttr "skinCluster1Set.mwc" "pCubeShape1.iog.og[4].gco";
connectAttr "groupId2.id" "pCubeShape1.iog.og[5].gid";
connectAttr "tweakSet1.mwc" "pCubeShape1.iog.og[5].gco";
connectAttr "skinCluster1.og[0]" "pCubeShape1.i";
connectAttr "tweak1.vl[0].vt[0]" "pCubeShape1.twl";
relationship "link" ":lightLinker1" ":initialShadingGroup.message" ":defaultLightSet.message";
relationship "link" ":lightLinker1" ":initialParticleSE.message" ":defaultLightSet.message";
relationship "shadowLink" ":lightLinker1" ":initialShadingGroup.message" ":defaultLightSet.message";
relationship "shadowLink" ":lightLinker1" ":initialParticleSE.message" ":defaultLightSet.message";
connectAttr "layerManager.dli[0]" "defaultLayer.id";
connectAttr "renderLayerManager.rlmi[0]" "defaultRenderLayer.rlid";
connectAttr "skinCluster1GroupParts.og" "skinCluster1.ip[0].ig";
connectAttr "skinCluster1GroupId.id" "skinCluster1.ip[0].gi";
connectAttr "bindPose2.msg" "skinCluster1.bp";
connectAttr "joint1.wm" "skinCluster1.ma[0]";
connectAttr "joint2.wm" "skinCluster1.ma[1]";
connectAttr "joint3.wm" "skinCluster1.ma[2]";
connectAttr "joint1.liw" "skinCluster1.lw[0]";
connectAttr "joint2.liw" "skinCluster1.lw[1]";
connectAttr "joint3.liw" "skinCluster1.lw[2]";
connectAttr "joint1.obcc" "skinCluster1.ifcl[0]";
connectAttr "joint2.obcc" "skinCluster1.ifcl[1]";
connectAttr "joint3.obcc" "skinCluster1.ifcl[2]";
connectAttr "groupParts2.og" "tweak1.ip[0].ig";
connectAttr "groupId2.id" "tweak1.ip[0].gi";
connectAttr "skinCluster1GroupId.msg" "skinCluster1Set.gn" -na;
connectAttr "pCubeShape1.iog.og[4]" "skinCluster1Set.dsm" -na;
connectAttr "skinCluster1.msg" "skinCluster1Set.ub[0]";
connectAttr "tweak1.og[0]" "skinCluster1GroupParts.ig";
connectAttr "skinCluster1GroupId.id" "skinCluster1GroupParts.gi";
connectAttr "groupId2.msg" "tweakSet1.gn" -na;
connectAttr "pCubeShape1.iog.og[5]" "tweakSet1.dsm" -na;
connectAttr "tweak1.msg" "tweakSet1.ub[0]";
connectAttr "pCubeShape1Orig.w" "groupParts2.ig";
connectAttr "groupId2.id" "groupParts2.gi";
connectAttr "joint1.msg" "bindPose2.m[0]";
connectAttr "joint2.msg" "bindPose2.m[1]";
connectAttr "joint3.msg" "bindPose2.m[2]";
connectAttr "bindPose2.w" "bindPose2.p[0]";
connectAttr "bindPose2.m[0]" "bindPose2.p[1]";
connectAttr "bindPose2.m[1]" "bindPose2.p[2]";
connectAttr "joint1.bps" "bindPose2.wm[0]";
connectAttr "joint2.bps" "bindPose2.wm[1]";
connectAttr "joint3.bps" "bindPose2.wm[2]";
connectAttr "defaultRenderLayer.msg" ":defaultRenderingList1.r" -na;
connectAttr "pCubeShape1.iog" ":initialShadingGroup.dsm" -na;
// End of ddm_box_smooth_32_tri.ma
