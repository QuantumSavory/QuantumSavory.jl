function c23=ret_c23(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF)
  %  Returns the (2,3) element of the spin-spin density matrix
  cf=@(Ns,n) sqrt((Ns.^n)./(Ns+1).^(n+1));
c0=cf(Ns,0);
c1=cf(Ns,1);
c2=cf(Ns,2);

c23=(1/64).*c0.^2.*c1.^4.*eAm.*eAs.^(1/2).*eBm.*eBs.^(1/2).*(c0.*eAs.^(1/2)+(-4).*c2.*(1+(-1).*eAs).^(1/2).*((-1).*((-1)+ ...
  eAs).*eAs).^(1/2).*((-1)+eD)).*(c0.*eBs.^(1/2)+(-4).*c2.*(1+(-1).*eBs).^(1/2).*((-1).*((-1)+eBs).*eBs).^(1/2).*((-1)+eD)).*eD.^2.*((-1).*((-1)+gA).*gA).^(1/2).*((-1).*((-1)+gB).*gB).^(1/2).*((-1)+Pd).^4.*((-1)+Pdo1).^4.*((-1)+Pdo2).^4.*  (VisF.^2);
end