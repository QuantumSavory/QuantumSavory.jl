function Mv=midswap_single_rail(eA,eB,gA,gB,Pd,Vis)
% Author: Prajit Dhara
% Function to calculate the spin-spin density matrix for midpoint swap
% using memories emitting single rail photonic qubits
% Inputs:
% eA, eB: Link efficiencies for memories A and B upto the swap (include link loss, detector efficiency, etc.)
%         Range: [0,1]; Typical value: 1-1e-4
% gA, gB: Memory initialization parameter for memories A and B 
%         Range: [0,1]; Typical value: 0.5 (set to achieve maximum hashing bound or reach target fidelity)
%         Memory emission model: \sqrt{1-g} |0>_M\otimes |1>_P + \sqrt{g} |1>_M\otimes |0>_P
% Pd: Detector dark count probability per photonic mode (assumed to be the same for both detectors)
%     Range: [0,1]; Typical value: 1e-8
% Vis: Interferometer visibility for the midpoint swap; can be a complex number to account for phase mismatch 
%     Range (absolute value):[0,1]; Typical value: 0.9-1
% Output:
% Mv: Spin-spin density matrix for the two memories after the midpoint swap
%     Basis: |00>, |01>, |10>, |11>
        m11=gA.*gB.*(1-Pd).*Pd;
        m22=(1/2).*eB.*gA.*(1-gB).*(1-Pd).^2 ...
            +(1-eB).*gA.*(1-gB).*(1-Pd).*Pd;

        m33=(1/2).*eA.*(1-gA).*gB.*(1-Pd).^2 ...
            +(1-eA).*(1-gA).*gB.*(1-Pd).*Pd;

        m23=(Vis).*(1/2).*((eA.*eB.*(1-gA).*gA.*(1-gB).*gB).^(1/2)).*(1-Pd).^2;

        m32=(Vis).*(1/2).*((eA.*eB.*(1-gA).*gA.*(1-gB).*gB).^(1/2)).*(1-Pd).^2;
        %
        m44=((1/2).*eB.*(1-eA).*(1-gA).*(1-gB)...
            +(1/2).*eA.*(1-eB).*(1-gA).*(1-gB)).*(1-Pd).^2 ...
            +(1-eA).*(1-eB).*(1-gA).*(1-gB).*(1-Pd).*Pd;
        %
        Mv=[m11, 0, 0, 0 ; 0, m22, m23, 0 ; 0, m32, m33, 0 ; 0, 0, 0, m44];
    
end