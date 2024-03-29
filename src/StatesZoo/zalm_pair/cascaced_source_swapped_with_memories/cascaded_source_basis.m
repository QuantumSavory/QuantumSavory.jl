function vec=cascaded_source_basis()
    % Returns the ordered basis for the density operator generated by 'cascaded_source_photonic.m'
    % Input: None
    % Output: vec - a 36x4 array of the basis vectors (we limit ourselves 
    %               to the Fock space of upto 2 photons in a pair of modes)

    vec=[0,0,0,0;0,0,0,1;0,0,0,2;0,0,1,0;0,0,1,1;0,0,2,0;0,1,0,0;0,1,0,1; ...
        0,1,0,2;0,1,1,0;0,1,1,1;0,1,2,0;0,2,0,0;0,2,0,1;0,2,0,2;0,2,1,0;0, ...
        2,1,1;0,2,2,0;1,0,0,0;1,0,0,1;1,0,0,2;1,0,1,0;1,0,1,1;1,0,2,0;1,1, ...
        0,0;1,1,0,1;1,1,0,2;1,1,1,0;1,1,1,1;1,1,2,0;2,0,0,0;2,0,0,1;2,0,0, ...
        2;2,0,1,0;2,0,1,1;2,0,2,0];
end