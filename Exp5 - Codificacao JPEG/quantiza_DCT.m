function [imagem_recuperada, Ydct, Cbdct, Crdct] = quantiza_DCT(Y, Cb, Cr, k)

%criando a imagem espelhada com padding
padY  = 8-mod(size(Y) ,8);
padCb = 8-mod(size(Cb) ,8);
padCr = 8-mod(size(Cr) ,8);

Y_pad =  padarray(Y, padY, 'symmetric', 'post');
Cb_pad = padarray(Cb, padCb, 'symmetric', 'post');
Cr_pad = padarray(Cr, padCr, 'symmetric', 'post');

%decimação por 2
Cb_sub = Cb_pad(1:2:end, 1:2:end);
Cr_sub = Cr_pad(1:2:end, 1:2:end);

%DCT aplicada a blocos 8x8 em cada canal
Ydct  = blkproc(Y_pad-128 , [8 8], @dct2);
Cbdct = blkproc(Cb_sub-128, [8 8], @dct2);
Crdct = blkproc(Cr_sub-128, [8 8], @dct2);

%Tabela de quantização Q
Q = [8 11 10 16 24 40 51 61;
    12 12 14 19 26 58 60 55;
    14 13 16 24 40 57 69 56;
    14 17 22 29 51 87 80 62;
    18 22 37 56 68 109 103 77;   
    24 35 55 64 81 104 113 92;
    49 64 78 87 103 121 120 101;
    72 92 95 98 112 100 103 99];

%quantização da DCT usando kQ como passo de quantização
q = k*Q;
xq = @(x) round(x./q);
Y_q  = blkproc(Ydct, [8 8], xq);
Cb_q = blkproc(Cbdct, [8 8], xq);
Cr_q = blkproc(Crdct, [8 8], xq);

%recuperação das imagens quantizadas

%Invertendo quantizador: 
xrec = @(x) (x.*q);
Y_iq  = blkproc(Y_q, [8 8], xrec);
Cb_iq = blkproc(Cb_q, [8 8], xrec);
Cr_iq = blkproc(Cr_q, [8 8], xrec);

%DCT inversa
Y_idct  = blkproc(Y_iq , [8 8], @idct2);
Cb_idct = blkproc(Cb_iq, [8 8], @idct2);
Cr_idct = blkproc(Cr_iq, [8 8], @idct2);

%somando 128 ao resultado
Y_idct = Y_idct + 128;
Cb_idct = Cb_idct + 128;
Cr_idct = Cr_idct + 128;

%interpolação linear usando o filtro h
h = [0.25 0.5 0.25; 0.5 1 0.5; 0.25 0.5 0.25];
Cb_interpolado = zeros(size(Cb_pad));
Cb_interpolado(1:2:end, 1:2:end) = Cb_idct;
Cb_interpolado = filter2(h, Cb_interpolado);

Cr_interpolado = zeros(size(Cr_pad));
Cr_interpolado(1:2:end, 1:2:end) = Cr_idct;
Cr_interpolado = filter2(h, Cr_interpolado);

%eliminando parte espelhada da imagem
Y_rec = Y_idct(1:end-padY(1), 1:end-padY(2));
Cb_rec = Cb_interpolado(1:end-padCb(1), 1:end-padCb(2));
Cr_rec = Cr_interpolado(1:end-padCr(1), 1:end-padCr(2));

%conversão para RGB
alpha_R = 0.299;
alpha_G = 0.587;
alpha_B = 0.114;
R_new = 2*(1-alpha_R)*Cr_rec + Y_rec;
B_new = 2*(1-alpha_B)*Cb_rec +Y_rec;
G_new = (Y_rec - alpha_R*R_new - alpha_B*B_new)/alpha_G;

%reuperação das imagens RGB
imagem_recuperada = cat(3, R_new, G_new, B_new);

