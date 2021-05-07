%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   PSI3531 - Processamento de Sinais Aplicado                      %
%                                                                   %
%   André Oliveira Françani     9017471                             %
%                                                                   %
%   Experiência 5 - Codificação de imagens segundo o padrão JPEG    %
%                                                                   % 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
clear
clc

gato = imread('cat.png');
gato = double(gato);
[N1, N2, c] = size(gato);
figure(1); imshow(uint8(gato));

%matrizes de pixels RGB
R = gato(:,:,1);
G = gato(:,:,2);
B = gato(:,:,3);

%transformação YCbCr
alpha_R = 0.299;
alpha_G = 0.587;
alpha_B = 0.114;

%Luminância Y
Y = alpha_R*R + alpha_G*G + alpha_B*B;

%termos de crominância: Cb e Cr
Cb = 1/(2*(1-alpha_B))*(B-Y);
Cr = 1/(2*(1-alpha_R))*(R-Y);

%Visualização do padrão YCbCr gerado
figure(2); 
subplot(1,3,1); imshow(uint8(Y) ); title('Y');
subplot(1,3,2); imshow(uint8(Cb)); title('C_b');
subplot(1,3,3); imshow(uint8(Cr)); title('C_r');

%% subamostragem por fator 2 nas direções vertical e horizontal
Cb_sub = Cb(1:2:end, 1:2:end);
Cr_sub = Cr(1:2:end, 1:2:end);

%interpolação linear usando o filtro
h = [0.25 0.5 0.25; 0.5 1 0.5; 0.25 0.5 0.25];

Cb_interpolado = zeros(size(Y));
Cb_interpolado(1:2:end, 1:2:end) = Cb_sub;
Cb_interpolado = filter2(h, Cb_interpolado);

Cr_interpolado = zeros(size(Y));
Cr_interpolado(1:2:end, 1:2:end) = Cr_sub;
Cr_interpolado = filter2(h, Cr_interpolado);

%conversão para RGB
R_new = 2*(1-alpha_R)*Cr_interpolado + Y;
B_new = 2*(1-alpha_B)*Cb_interpolado + Y;
G_new = (Y - alpha_R*R_new - alpha_B*B_new)/alpha_G;

%reuperação da imagem RGB
gato_recuperado = cat(3, R_new, G_new, B_new);

figure(3)
subplot(1,2,1); imshow(uint8(gato)); title('imagem original');
subplot(1,2,2); imshow(uint8(gato_recuperado)); title('imagem recuperada');

%Cálculo da PSNR
Bits = 8; 
MSE = (abs(gato-gato_recuperado).^2)/(N1*N2);
MSE = sum(MSE, [1,2]);
MSE = mean(MSE,3);
PSNR = 10*log10((2^Bits-1)^2/MSE);

%% Quantização da DCT

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

%% Tabela de quantização Q
Q = [8 11 10 16 24 40 51 61;
    12 12 14 19 26 58 60 55;
    14 13 16 24 40 57 69 56;
    14 17 22 29 51 87 80 62;
    18 22 37 56 68 109 103 77;   
    24 35 55 64 81 104 113 92;
    49 64 78 87 103 121 120 101;
    72 92 95 98 112 100 103 99];

%inicializando as variáveis
Y_q  = zeros(3,size(Ydct,1), size(Ydct,2));
Cb_q = zeros(3,size(Cbdct,1), size(Cbdct,2));
Cr_q = zeros(3,size(Crdct,1), size(Crdct,2));

%quantização da DCT usando kQ como passo de quantização
k = 1;

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

%interpolação linear usando o mesmo filtro h
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
R_new = 2*(1-alpha_R)*Cr_rec + Y_rec;
B_new = 2*(1-alpha_B)*Cb_rec +Y_rec;
G_new = (Y_rec - alpha_R*R_new - alpha_B*B_new)/alpha_G;

%reuperação das imagens RGB
imagem_recuperada = cat(3, R_new, G_new, B_new);

%Cálculo da PSNR
Bits = 8; 
MSE = (abs(gato-imagem_recuperada).^2)/(N1*N2);
MSE = sum(MSE, [1,2]);
MSE = mean(MSE,3);
PSNR = 10*log10((2^Bits-1)^2/MSE)

figure(5);
imshow(uint8(imagem_recuperada))
