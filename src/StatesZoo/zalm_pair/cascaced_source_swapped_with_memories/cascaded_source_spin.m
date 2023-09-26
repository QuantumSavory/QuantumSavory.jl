function Mv=cascaded_source_spin(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF)
% Author: Prajit Dhara
% Function to calculate the spin-spin density matrix from a cascaded source swapped
% memories emitting dual-rail photonic qubit on linear optical Bell state measurement circuits
% Inputs:
% Ns: mean photon number per mode of the cascaded source model
% gA: qubit initialization parameter on Alice's side (Allowed range: [0,1])
% gB: qubit initialization parameter on Bob's side (Allowed range: [0,1])
% eAm: memory out-coupling efficiency for Alice's side (Allowed range: [0,1])
%   Allowed range: [0,1]
%   Typical value: 1-0.5
% eBm: memory out-coupling efficiency for Bob's side (Allowed range: [0,1])
%   Allowed range: [0,1]
%   Typical value: 1-0.5
% eAs: source out-coupling efficiency for Alice's side (Allowed range: [0,1])
%   Allowed range: [0,1]
%   Typical value: 1-1e-4
% eBs: source out-coupling efficiency for Bob's side (Allowed range: [0,1])
%   Allowed range: [0,1]
%   Typical value: 1-1e-4
% eD: detector efficiency (Allowed range: [0,1])
%   Allowed range: [0,1]
%   Typical value: 0.9
% Pd: dark click probability per photonic mode on source's swap (Allowed range: [0,1))
%   Allowed range: [0,1)
%   Typical value: 1e-8
% Pdo1: dark click probability per photonic mode on Alice side swap (Allowed range: [0,1))
%   Allowed range: [0,1)
%   Typical value: 1e-8
% Pdo2: dark click probability per photonic mode on Bob side swap (Allowed range: [0,1))
%   Allowed range: [0,1)
%   Typical value: 1e-8
% VisF: product of visibilities of all three  interferometers (Allowed range: [0,1])
%   Allowed range: [0,1]
%   Typical value: 0.9
% Outputs:
% M: Output spin state density matrix of the cascaded source 
%    (in the logical spin basis)
% Basis order: |00>, |01>, |10>, |11>

m11=ret_c11(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF);
m22=ret_c22(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF);
m33=ret_c33(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF);
m44=ret_c44(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF);
m23=ret_c23(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF);
m32=conj(m23);

Mv=[m11, 0, 0, 0 ; 0, m22, m23, 0 ; 0, m32, m33, 0 ; 0, 0, 0, m44];

end


