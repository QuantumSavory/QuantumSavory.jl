function c44=ret_c44(Ns,gA,gB,eAm,eBm,eAs,eBs,eD,Pd,Pdo1,Pdo2,VisF)
  %  Returns the (4,4) element of the spin-spin density matrix
  cf=@(Ns,n) sqrt((Ns.^n)./(Ns+1).^(n+1));
c0=cf(Ns,0);
c1=cf(Ns,1);
c2=cf(Ns,2);

c44=(1/32).*((-1)+gA).*(1+(-1).*gB).*((-1)+Pd).^2.*((-1)+Pdo1).* ...
  ((-1).*eBs.*(2.*c0.^6.*eBm.*Pd.*(4.*c2.^2.*((-1)+eBs).*((-1) ...
  +eD).*((-1).*Pd+eD.*((-1)+2.*Pd))+c1.^2.*((-2).*Pd+eD.*((-1) ...
  +3.*Pd))).*Pdo1.^2.*(2+(-2).*Pdo1+eAm.*((-2)+3.*Pdo1))+2.* ...
  c1.^8.*((-1).*eBs+eBm.*((-1)+2.*eBs)).*((-1)+eD).^2.*(eD+Pd+ ...
  (-2).*eD.*Pd).^2.*((-4).*((-1)+Pdo1).*Pdo1.^2+4.*eAs.* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+eAs.^2.*(1+(-3).*Pdo1+7.*Pdo1.^2+( ...
  -9).*Pdo1.^3)+eAm.*(2.*Pdo1.^2.*((-2)+3.*Pdo1)+eAs.*(1+(-3) ...
  .*Pdo1+11.*Pdo1.^2+(-17).*Pdo1.^3)+2.*eAs.^2.*((-1)+3.*Pdo1+ ...
  (-5).*Pdo1.^2+6.*Pdo1.^3)))+c0.^2.*c1.^4.*((-1)+eD).*((-2).* ...
  Pd+eD.*((-1)+3.*Pd)).*(c1.^2.*((-1).*Pd+eD.*((-1)+2.*Pd)).*( ...
  4.*((-2).*eBs+eBm.*((-3)+4.*eBs)).*((-1)+Pdo1).*Pdo1.^2+(-4) ...
  .*eAs.*(2.*eBm.*((-1)+eBs)+(-1).*eBs).*Pdo1.^2.*((-2)+3.* ...
  Pdo1)+eAs.^2.*eBm.*(1+(-3).*Pdo1+7.*Pdo1.^2+(-9).*Pdo1.^3)+ ...
  eAm.*((-2).*((-2).*eBs+eBm.*((-3)+4.*eBs)).*Pdo1.^2.*((-2)+ ...
  3.*Pdo1)+2.*eAs.^2.*eBm.*((-1)+3.*Pdo1+(-5).*Pdo1.^2+6.* ...
  Pdo1.^3)+eAs.*(2.*eBm.*((-1)+eBs)+(-1).*eBs).*((-1)+3.*Pdo1+ ...
  (-11).*Pdo1.^2+17.*Pdo1.^3)))+c2.^2.*((-1)+eD).*((-2).*Pd+ ...
  eD.*((-3)+5.*Pd)).*((-4).*((-1).*eBs+eBm.*((-2)+3.*eBs)).*(( ...
  -1)+Pdo1).*Pdo1.^2+4.*eAs.*((-1).*eBs+eBm.*((-2)+3.*eBs)).* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+eAs.^2.*(4.*eBs.*Pdo1.^2.*((-1)+2.* ...
  Pdo1)+eBm.*((-1)+eBs+3.*Pdo1+(-3).*eBs.*Pdo1+(-11).*Pdo1.^2+ ...
  15.*eBs.*Pdo1.^2+17.*Pdo1.^3+(-25).*eBs.*Pdo1.^3))+eAm.*(2.* ...
  ((-1).*eBs+eBm.*((-2)+3.*eBs)).*Pdo1.^2.*((-2)+3.*Pdo1)+(-1) ...
  .*eAs.*((-1).*eBs+eBm.*((-2)+3.*eBs)).*((-1)+3.*Pdo1+(-11).* ...
  Pdo1.^2+17.*Pdo1.^3)+eAs.^2.*(eBs.*(1+(-3).*Pdo1+7.*Pdo1.^2+ ...
  (-11).*Pdo1.^3)+eBm.*(3+(-9).*Pdo1+17.*Pdo1.^2+(-23).* ...
  Pdo1.^3+2.*eBs.*((-2)+6.*Pdo1+(-12).*Pdo1.^2+17.*Pdo1.^3)))) ...
  ))+c0.^4.*(c1.^4.*(Pdo1.^2.*(2.*eBs.*(eD+2.*Pd+(-3).*eD.*Pd) ...
  .^2.*((-1)+Pdo1)+eBm.*((-8).*Pd.^2.*(((-3)+2.*eBs).*((-1)+ ...
  Pdo1)+eAs.*((-2)+3.*Pdo1))+8.*eD.*Pd.*((-1)+3.*Pd).*(((-3)+ ...
  2.*eBs).*((-1)+Pdo1)+eAs.*((-2)+3.*Pdo1))+eD.^2.*((-4).*(( ...
  -1)+eBs.*(1+(-3).*Pd).^2+8.*Pd+(-13).*Pd.^2).*((-1)+Pdo1)+( ...
  -1).*eAs.*(1+(-10).*Pd+17.*Pd.^2).*((-2)+3.*Pdo1))))+eAm.*(( ...
  (-1).*eBs.*(eD+2.*Pd+(-3).*eD.*Pd).^2+2.*eBm.*(2.*((-3)+2.* ...
  eBs).*Pd.^2+(-2).*((-3)+2.*eBs).*eD.*Pd.*((-1)+3.*Pd)+ ...
  eD.^2.*((-1)+eBs.*(1+(-3).*Pd).^2+8.*Pd+(-13).*Pd.^2))).* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+2.*eAs.*eBm.*(Pd.^2.*((-1)+3.*Pdo1+( ...
  -11).*Pdo1.^2+17.*Pdo1.^3)+(-1).*eD.*Pd.*((-1)+3.*Pd).*((-1) ...
  +3.*Pdo1+(-11).*Pdo1.^2+17.*Pdo1.^3)+eD.^2.*(Pdo1.^2.*((-1)+ ...
  2.*Pdo1)+Pd.*(1+(-3).*Pdo1+13.*Pdo1.^2+(-21).*Pdo1.^3)+ ...
  Pd.^2.*((-2)+6.*Pdo1+(-23).*Pdo1.^2+36.*Pdo1.^3)))))+8.* ...
  c2.^4.*((-1)+eAs).*eBm.*((-1)+eBs).*((-1)+eD).^2.*((-2).*( ...
  4.*eD.*(1+(-2).*Pd).*Pd+2.*Pd.^2+eD.^2.*(1+(-6).*Pd+7.* ...
  Pd.^2)).*Pdo1.^2.*(1+(-1).*Pdo1+eAs.*((-1)+2.*Pdo1))+eAm.*(( ...
  -1).*(4.*eD.*(1+(-2).*Pd).*Pd+2.*Pd.^2+eD.^2.*(1+(-6).*Pd+ ...
  7.*Pd.^2)).*Pdo1.^2.*((-2)+3.*Pdo1)+eAs.*(Pd.^2.*((-1)+3.* ...
  Pdo1+(-7).*Pdo1.^2+11.*Pdo1.^3)+(-2).*eD.*Pd.*((-1)+2.*Pd).* ...
  ((-1)+3.*Pdo1+(-7).*Pdo1.^2+11.*Pdo1.^3)+eD.^2.*(Pdo1.^2.*(( ...
  -2)+5.*Pdo1)+Pd.*(2+(-6).*Pdo1+18.*Pdo1.^2+(-32).*Pdo1.^3)+ ...
  Pd.^2.*((-3)+9.*Pdo1+(-23).*Pdo1.^2+38.*Pdo1.^3)))))+2.* ...
  c1.^2.*c2.^2.*eBm.*((-1)+eD).*((-2).*(2.*eD.*(3+(-7).*Pd).* ...
  Pd+4.*Pd.^2+eD.^2.*(1+(-8).*Pd+11.*Pd.^2)).*Pdo1.^2.*((-1).* ...
  ((-3)+2.*eBs).*((-1)+Pdo1)+eAs.^2.*((-1)+2.*Pdo1)+eAs.*((-2) ...
  +eBs).*((-2)+3.*Pdo1))+eAm.*((-1).*((-3)+2.*eBs).*(2.*eD.*( ...
  3+(-7).*Pd).*Pd+4.*Pd.^2+eD.^2.*(1+(-8).*Pd+11.*Pd.^2)).* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+eAs.^2.*(2.*Pd.^2.*((-1)+3.*Pdo1+( ...
  -7).*Pdo1.^2+11.*Pdo1.^3)+(-1).*eD.*Pd.*((-3)+7.*Pd).*((-1)+ ...
  3.*Pdo1+(-7).*Pdo1.^2+11.*Pdo1.^3)+eD.^2.*(Pdo1.^2.*((-2)+ ...
  5.*Pdo1)+Pd.*(3+(-9).*Pdo1+25.*Pdo1.^2+(-43).*Pdo1.^3)+ ...
  Pd.^2.*((-5)+15.*Pdo1+(-37).*Pdo1.^2+60.*Pdo1.^3)))+eAs.*(( ...
  -2)+eBs).*(2.*Pd.^2.*((-1)+3.*Pdo1+(-11).*Pdo1.^2+17.* ...
  Pdo1.^3)+(-1).*eD.*Pd.*((-3)+7.*Pd).*((-1)+3.*Pdo1+(-11).* ...
  Pdo1.^2+17.*Pdo1.^3)+eD.^2.*(4.*Pdo1.^2.*((-1)+2.*Pdo1)+Pd.* ...
  (3+(-9).*Pdo1+41.*Pdo1.^2+(-67).*Pdo1.^3)+Pd.^2.*((-5)+15.* ...
  Pdo1+(-59).*Pdo1.^2+93.*Pdo1.^3))))))).*((-1)+Pdo2).^4+2.*( ...
  1+(-1).*eBm).*(8.*c0.^8.*Pd.^2.*Pdo1.^2.*(2+(-2).*Pdo1+eAm.* ...
  ((-2)+3.*Pdo1))+4.*c1.^8.*((-1)+eBs).^2.*((-1)+eD).^2.*(eD+ ...
  Pd+(-2).*eD.*Pd).^2.*((-4).*((-1)+Pdo1).*Pdo1.^2+4.*eAs.* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+eAs.^2.*(1+(-3).*Pdo1+7.*Pdo1.^2+( ...
  -9).*Pdo1.^3)+eAm.*(2.*Pdo1.^2.*((-2)+3.*Pdo1)+eAs.*(1+(-3) ...
  .*Pdo1+11.*Pdo1.^2+(-17).*Pdo1.^3)+2.*eAs.^2.*((-1)+3.*Pdo1+ ...
  (-5).*Pdo1.^2+6.*Pdo1.^3)))+2.*c0.^6.*Pd.*(4.*c2.^2.*((-1)+ ...
  eD).*((-1).*Pd+eD.*((-1)+2.*Pd)).*(4.*Pdo1.^2.*(eAs.^2.*(1+( ...
  -2).*Pdo1)+(-1).*(2+(-2).*eBs+eBs.^2).*((-1)+Pdo1)+eAs.*(( ...
  -2)+3.*Pdo1))+eAm.*(2.*(2+(-2).*eBs+eBs.^2).*Pdo1.^2.*((-2)+ ...
  3.*Pdo1)+eAs.*(1+(-3).*Pdo1+11.*Pdo1.^2+(-17).*Pdo1.^3)+ ...
  eAs.^2.*((-1)+3.*Pdo1+(-7).*Pdo1.^2+11.*Pdo1.^3)))+c1.^2.*(( ...
  -2).*Pd+eD.*((-1)+3.*Pd)).*(4.*(eAs.*(2+(-3).*Pdo1)+(-2).*(( ...
  -2)+eBs).*((-1)+Pdo1)).*Pdo1.^2+eAm.*(4.*((-2)+eBs).* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+eAs.*((-1)+3.*Pdo1+(-11).*Pdo1.^2+ ...
  17.*Pdo1.^3))))+c0.^4.*(8.*c2.^4.*((-1)+eAs).*((-1)+eBs) ...
  .^2.*((-1)+eD).^2.*(4.*eD.*(1+(-2).*Pd).*Pd+2.*Pd.^2+eD.^2.* ...
  (1+(-6).*Pd+7.*Pd.^2)).*(2.*eAm.*(2+(-3).*Pdo1).*Pdo1.^2+4.* ...
  Pdo1.^2.*((-1)+eAs+Pdo1+(-2).*eAs.*Pdo1)+eAm.*eAs.*((-1)+3.* ...
  Pdo1+(-7).*Pdo1.^2+11.*Pdo1.^3))+2.*c1.^2.*c2.^2.*((-1)+eBs) ...
  .*((-1)+eD).*(2.*eD.*(3+(-7).*Pd).*Pd+4.*Pd.^2+eD.^2.*(1+( ...
  -8).*Pd+11.*Pd.^2)).*((-4).*Pdo1.^2.*((-2).*((-2)+eBs).*(( ...
  -1)+Pdo1)+eAs.*((-3)+eBs).*((-2)+3.*Pdo1)+eAs.^2.*((-2)+4.* ...
  Pdo1))+eAm.*((-4).*((-2)+eBs).*Pdo1.^2.*((-2)+3.*Pdo1)+2.* ...
  eAs.^2.*((-1)+3.*Pdo1+(-7).*Pdo1.^2+11.*Pdo1.^3)+eAs.*((-3)+ ...
  eBs).*((-1)+3.*Pdo1+(-11).*Pdo1.^2+17.*Pdo1.^3)))+c1.^4.*(( ...
  -4).*(4.*(6+(-6).*eBs+eBs.^2).*Pd.^2+(-4).*(6+(-6).*eBs+ ...
  eBs.^2).*eD.*Pd.*((-1)+3.*Pd)+eD.^2.*(4+eBs.^2.*(1+(-3).*Pd) ...
  .^2+(-32).*Pd+52.*Pd.^2+(-4).*eBs.*(1+(-8).*Pd+13.*Pd.^2))) ...
  .*((-1)+Pdo1).*Pdo1.^2+(-4).*eAs.*(4.*((-3)+2.*eBs).*Pd.^2+( ...
  -4).*((-3)+2.*eBs).*eD.*Pd.*((-1)+3.*Pd)+eD.^2.*((-2)+eBs+ ...
  16.*Pd+(-10).*eBs.*Pd+(-26).*Pd.^2+17.*eBs.*Pd.^2)).* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+(-1).*eAs.^2.*(eD+2.*Pd+(-3).*eD.* ...
  Pd).^2.*((-1)+3.*Pdo1+(-7).*Pdo1.^2+9.*Pdo1.^3)+eAm.*(2.*( ...
  4.*(6+(-6).*eBs+eBs.^2).*Pd.^2+(-4).*(6+(-6).*eBs+eBs.^2).* ...
  eD.*Pd.*((-1)+3.*Pd)+eD.^2.*(4+eBs.^2.*(1+(-3).*Pd).^2+(-32) ...
  .*Pd+52.*Pd.^2+(-4).*eBs.*(1+(-8).*Pd+13.*Pd.^2))).* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+2.*eAs.^2.*(eD+2.*Pd+(-3).*eD.*Pd) ...
  .^2.*((-1)+3.*Pdo1+(-5).*Pdo1.^2+6.*Pdo1.^3)+eAs.*(4.*((-3)+ ...
  2.*eBs).*Pd.^2+(-4).*((-3)+2.*eBs).*eD.*Pd.*((-1)+3.*Pd)+ ...
  eD.^2.*((-2)+eBs+16.*Pd+(-10).*eBs.*Pd+(-26).*Pd.^2+17.* ...
  eBs.*Pd.^2)).*((-1)+3.*Pdo1+(-11).*Pdo1.^2+17.*Pdo1.^3))))+ ...
  2.*c0.^2.*c1.^4.*((-1)+eBs).*((-1)+eD).*((-2).*Pd+eD.*((-1)+ ...
  3.*Pd)).*(c1.^2.*((-1).*Pd+eD.*((-1)+2.*Pd)).*(8.*((-2)+eBs) ...
  .*((-1)+Pdo1).*Pdo1.^2+(-4).*eAs.*((-3)+eBs).*Pdo1.^2.*((-2) ...
  +3.*Pdo1)+(-2).*eAs.^2.*((-1)+3.*Pdo1+(-7).*Pdo1.^2+9.* ...
  Pdo1.^3)+eAm.*((-4).*((-2)+eBs).*Pdo1.^2.*((-2)+3.*Pdo1)+4.* ...
  eAs.^2.*((-1)+3.*Pdo1+(-5).*Pdo1.^2+6.*Pdo1.^3)+eAs.*((-3)+ ...
  eBs).*((-1)+3.*Pdo1+(-11).*Pdo1.^2+17.*Pdo1.^3)))+c2.^2.*(( ...
  -1)+eBs).*((-1)+eD).*((-2).*Pd+eD.*((-3)+5.*Pd)).*((-8).*(( ...
  -1)+Pdo1).*Pdo1.^2+8.*eAs.*Pdo1.^2.*((-2)+3.*Pdo1)+eAs.^2.*( ...
  1+(-3).*Pdo1+11.*Pdo1.^2+(-17).*Pdo1.^3)+eAm.*(4.*Pdo1.^2.*( ...
  (-2)+3.*Pdo1)+eAs.*(2+(-6).*Pdo1+22.*Pdo1.^2+(-34).*Pdo1.^3) ...
  +eAs.^2.*((-3)+9.*Pdo1+(-17).*Pdo1.^2+23.*Pdo1.^3))))).*(( ...
  -1)+Pdo2).^2.*Pdo2.^2+(8.*c0.^8.*eBm.*Pd.^2.*Pdo1.^2.*(2+( ...
  -2).*Pdo1+eAm.*((-2)+3.*Pdo1))+4.*c1.^8.*((-1)+eBs).*((-2).* ...
  eBs+eBm.*((-1)+3.*eBs)).*((-1)+eD).^2.*(eD+Pd+(-2).*eD.*Pd) ...
  .^2.*((-4).*((-1)+Pdo1).*Pdo1.^2+4.*eAs.*Pdo1.^2.*((-2)+3.* ...
  Pdo1)+eAs.^2.*(1+(-3).*Pdo1+7.*Pdo1.^2+(-9).*Pdo1.^3)+eAm.*( ...
  2.*Pdo1.^2.*((-2)+3.*Pdo1)+eAs.*(1+(-3).*Pdo1+11.*Pdo1.^2+( ...
  -17).*Pdo1.^3)+2.*eAs.^2.*((-1)+3.*Pdo1+(-5).*Pdo1.^2+6.* ...
  Pdo1.^3)))+2.*c0.^2.*c1.^4.*((-1)+eD).*((-2).*Pd+eD.*((-1)+ ...
  3.*Pd)).*(c1.^2.*((-1).*Pd+eD.*((-1)+2.*Pd)).*(8.*((3+(-2).* ...
  eBs).*eBs+eBm.*(2+(-6).*eBs+3.*eBs.^2)).*((-1)+Pdo1).* ...
  Pdo1.^2+(-4).*eAs.*((-2).*((-2)+eBs).*eBs+eBm.*(3+(-8).*eBs+ ...
  3.*eBs.^2)).*Pdo1.^2.*((-2)+3.*Pdo1)+(-2).*eAs.^2.*((-1).* ...
  eBs+eBm.*((-1)+2.*eBs)).*((-1)+3.*Pdo1+(-7).*Pdo1.^2+9.* ...
  Pdo1.^3)+eAm.*((-4).*((3+(-2).*eBs).*eBs+eBm.*(2+(-6).*eBs+ ...
  3.*eBs.^2)).*Pdo1.^2.*((-2)+3.*Pdo1)+4.*eAs.^2.*((-1).*eBs+ ...
  eBm.*((-1)+2.*eBs)).*((-1)+3.*Pdo1+(-5).*Pdo1.^2+6.*Pdo1.^3) ...
  +eAs.*((-2).*((-2)+eBs).*eBs+eBm.*(3+(-8).*eBs+3.*eBs.^2)).* ...
  ((-1)+3.*Pdo1+(-11).*Pdo1.^2+17.*Pdo1.^3)))+c2.^2.*((-1)+ ...
  eBs).*((-2).*eBs+eBm.*((-1)+3.*eBs)).*((-1)+eD).*((-2).*Pd+ ...
  eD.*((-3)+5.*Pd)).*((-8).*((-1)+Pdo1).*Pdo1.^2+8.*eAs.* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+eAs.^2.*(1+(-3).*Pdo1+11.*Pdo1.^2+( ...
  -17).*Pdo1.^3)+eAm.*(4.*Pdo1.^2.*((-2)+3.*Pdo1)+eAs.*(2+(-6) ...
  .*Pdo1+22.*Pdo1.^2+(-34).*Pdo1.^3)+eAs.^2.*((-3)+9.*Pdo1+( ...
  -17).*Pdo1.^2+23.*Pdo1.^3))))+2.*c0.^6.*Pd.*(c1.^2.*((-2).* ...
  Pd+eD.*((-1)+3.*Pd)).*((-4).*Pdo1.^2.*(4.*eBm.*((-1)+eBs).*( ...
  (-1)+Pdo1)+(-2).*eBs.*((-1)+Pdo1)+eAs.*eBm.*((-2)+3.*Pdo1))+ ...
  eAm.*(4.*(2.*eBm.*((-1)+eBs)+(-1).*eBs).*Pdo1.^2.*((-2)+3.* ...
  Pdo1)+eAs.*eBm.*((-1)+3.*Pdo1+(-11).*Pdo1.^2+17.*Pdo1.^3)))+ ...
  4.*c2.^2.*((-1)+eD).*((-1).*Pd+eD.*((-1)+2.*Pd)).*(eAm.*(2.* ...
  ((-2).*((-1)+eBs).*eBs+eBm.*(2+(-4).*eBs+3.*eBs.^2)).* ...
  Pdo1.^2.*((-2)+3.*Pdo1)+eAs.*eBm.*(1+(-3).*Pdo1+11.*Pdo1.^2+ ...
  (-17).*Pdo1.^3)+eAs.^2.*eBm.*((-1)+3.*Pdo1+(-7).*Pdo1.^2+ ...
  11.*Pdo1.^3))+(-4).*Pdo1.^2.*(2.*eBs.*((-1)+eBs+Pdo1+(-1).* ...
  eBs.*Pdo1)+eBm.*(eAs.*(2+(-3).*Pdo1)+(2+(-4).*eBs+3.*eBs.^2) ...
  .*((-1)+Pdo1)+eAs.^2.*((-1)+2.*Pdo1)))))+c0.^4.*(8.*c2.^4.*( ...
  (-1)+eAs).*((-1)+eBs).*((-2).*eBs+eBm.*((-1)+3.*eBs)).*((-1) ...
  +eD).^2.*(4.*eD.*(1+(-2).*Pd).*Pd+2.*Pd.^2+eD.^2.*(1+(-6).* ...
  Pd+7.*Pd.^2)).*(2.*eAm.*(2+(-3).*Pdo1).*Pdo1.^2+4.*Pdo1.^2.* ...
  ((-1)+eAs+Pdo1+(-2).*eAs.*Pdo1)+eAm.*eAs.*((-1)+3.*Pdo1+(-7) ...
  .*Pdo1.^2+11.*Pdo1.^3))+c1.^4.*((-4).*((-2).*eBs.*(4.*((-3)+ ...
  eBs).*Pd.^2+(-4).*((-3)+eBs).*eD.*Pd.*((-1)+3.*Pd)+eD.^2.*(( ...
  -2)+eBs.*(1+(-3).*Pd).^2+16.*Pd+(-26).*Pd.^2))+eBm.*(12.*(2+ ...
  (-4).*eBs+eBs.^2).*Pd.^2+(-12).*(2+(-4).*eBs+eBs.^2).*eD.* ...
  Pd.*((-1)+3.*Pd)+eD.^2.*(4+3.*eBs.^2.*(1+(-3).*Pd).^2+(-32) ...
  .*Pd+52.*Pd.^2+(-8).*eBs.*(1+(-8).*Pd+13.*Pd.^2)))).*((-1)+ ...
  Pdo1).*Pdo1.^2+(-4).*eAs.*((-1).*eBs.*(8.*eD.*(1+(-3).*Pd).* ...
  Pd+8.*Pd.^2+eD.^2.*(1+(-10).*Pd+17.*Pd.^2))+2.*eBm.*(2.*(( ...
  -3)+4.*eBs).*Pd.^2+(-2).*((-3)+4.*eBs).*eD.*Pd.*((-1)+3.*Pd) ...
  +eD.^2.*((-1)+eBs+8.*Pd+(-10).*eBs.*Pd+(-13).*Pd.^2+17.* ...
  eBs.*Pd.^2))).*Pdo1.^2.*((-2)+3.*Pdo1)+(-1).*eAs.^2.*eBm.*( ...
  eD+2.*Pd+(-3).*eD.*Pd).^2.*((-1)+3.*Pdo1+(-7).*Pdo1.^2+9.* ...
  Pdo1.^3)+eAm.*(2.*((-2).*eBs.*(4.*((-3)+eBs).*Pd.^2+(-4).*(( ...
  -3)+eBs).*eD.*Pd.*((-1)+3.*Pd)+eD.^2.*((-2)+eBs.*(1+(-3).* ...
  Pd).^2+16.*Pd+(-26).*Pd.^2))+eBm.*(12.*(2+(-4).*eBs+eBs.^2) ...
  .*Pd.^2+(-12).*(2+(-4).*eBs+eBs.^2).*eD.*Pd.*((-1)+3.*Pd)+ ...
  eD.^2.*(4+3.*eBs.^2.*(1+(-3).*Pd).^2+(-32).*Pd+52.*Pd.^2+( ...
  -8).*eBs.*(1+(-8).*Pd+13.*Pd.^2)))).*Pdo1.^2.*((-2)+3.*Pdo1) ...
  +2.*eAs.^2.*eBm.*(eD+2.*Pd+(-3).*eD.*Pd).^2.*((-1)+3.*Pdo1+( ...
  -5).*Pdo1.^2+6.*Pdo1.^3)+eAs.*((-1).*eBs.*(8.*eD.*(1+(-3).* ...
  Pd).*Pd+8.*Pd.^2+eD.^2.*(1+(-10).*Pd+17.*Pd.^2))+2.*eBm.*( ...
  2.*((-3)+4.*eBs).*Pd.^2+(-2).*((-3)+4.*eBs).*eD.*Pd.*((-1)+ ...
  3.*Pd)+eD.^2.*((-1)+eBs+8.*Pd+(-10).*eBs.*Pd+(-13).*Pd.^2+ ...
  17.*eBs.*Pd.^2))).*((-1)+3.*Pdo1+(-11).*Pdo1.^2+17.*Pdo1.^3) ...
  ))+2.*c1.^2.*c2.^2.*((-1)+eD).*(2.*eD.*(3+(-7).*Pd).*Pd+4.* ...
  Pd.^2+eD.^2.*(1+(-8).*Pd+11.*Pd.^2)).*(eAm.*((-4).*((3+(-2) ...
  .*eBs).*eBs+eBm.*(2+(-6).*eBs+3.*eBs.^2)).*Pdo1.^2.*((-2)+ ...
  3.*Pdo1)+2.*eAs.^2.*((-1).*eBs+eBm.*((-1)+2.*eBs)).*((-1)+ ...
  3.*Pdo1+(-7).*Pdo1.^2+11.*Pdo1.^3)+eAs.*((-2).*((-2)+eBs).* ...
  eBs+eBm.*(3+(-8).*eBs+3.*eBs.^2)).*((-1)+3.*Pdo1+(-11).* ...
  Pdo1.^2+17.*Pdo1.^3))+(-4).*Pdo1.^2.*(2.*eBs.*(eAs.^2.*(1+( ...
  -2).*Pdo1)+((-3)+2.*eBs).*((-1)+Pdo1)+(-1).*eAs.*((-2)+eBs) ...
  .*((-2)+3.*Pdo1))+eBm.*((-2).*(2+(-6).*eBs+3.*eBs.^2).*((-1) ...
  +Pdo1)+2.*eAs.^2.*((-1)+2.*eBs).*((-1)+2.*Pdo1)+eAs.*(3+(-8) ...
  .*eBs+3.*eBs.^2).*((-2)+3.*Pdo1)))))).*(1+(-1).*Pdo2).* ...
  Pdo2.^3);

end