create or replace
PACKAGE BODY            "PCT_OPL" AS


  /*
     Procedimento......: SP_VALIDACAO_INICIAL_OPL
     Descricao.........: FAZ A VALIDACAO INICIAL DO PEDIDO
     Dt.Criacao/Autor..: ( 25/08/2011 ) - RODRIGO VIDAL
  */
  PROCEDURE SP_VALIDACAO_INICIAL_OPL( nID_OPL_PEDIDO           IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE) 
     
  IS 
   CURSOR C_PEDIDOS IS 
      SELECT OPL_PEDIDO.ID_OPL_PEDIDO,
             OPL_PEDIDO.DT_EMISSAO, 
             OPL_PEDIDO.NR_CNPJ_CLIENTE, 
             OPL_PEDIDO.ID_TIPO_PAGAMENTO, 
             OPL_PEDIDO.COND_PGTO_ARQ, 
             OPL_PEDIDO_ITEM.ID_EAN, 
             OPL_PEDIDO_ITEM.QTDE_PEDIDA,
             OPL_PEDIDO_ITEM.QTDE_ATENDIDA,
             OPL_PEDIDO_ITEM.NR_ITEM
        FROM OPL_PEDIDO, 
             OPL_PEDIDO_ITEM 
       WHERE OPL_PEDIDO_ITEM.ID_OPL_PEDIDO  = OPL_PEDIDO.ID_OPL_PEDIDO
         AND OPL_PEDIDO.DM_STATUS           IN (   '1' , '9' )                                              
         AND OPL_PEDIDO.ID_OPL_PEDIDO       = nID_OPL_PEDIDO
         ORDER BY NR_ITEM ;           
  
   TRPedidos                            C_PEDIDOS%ROWTYPE;
   NID_PESSOA                           GE_PESSOA.ID_PESSOA%TYPE;
   nNR_CNPJ_CLIENTE                     OPL_PEDIDO.NR_CNPJ_CLIENTE%TYPE;
   nID_PRODUTO                          ES_PRODUTO.ID_PRODUTO%TYPE;
   vcSitProduto                         ES_PRODUTO.DM_SITUACAO%TYPE;
   nHR_MAX                              DATE;
   vcDS_OBSERVACAO                      OPL_PEDIDO.DS_OBSERVACAO%TYPE;
   VCDM_BLOQUEADO                       VARCHAR2(1);
   VCDS_MOTIVO_BLOQUEIO                 VARCHAR2(155);
   NVL_LIMITE_CREDITO                   NUMBER;
   NVL_TITULOS_ABERTO                   NUMBER;
   NVL_LIMITE_DISPONIVEL                NUMBER;
   NVL_TITULOS_ATRASO                   NUMBER;
   nQTD_Saldo                           NUMBER;
   nQTD_Atendida                        NUMBER;
   nTOTAL_PEDIDO                        NUMBER;
   nID_PROJETO                          OPL_PEDIDO.ID_PROJETO%TYPE;
   vcCOND_ARQ                           OPL_PEDIDO.COND_PGTO_ARQ%TYPE;
   nID_CONDICAO_PGTO                    NUMBER;
   nID_CONDICAO_PGTO_CLI                NUMBER;
   nDESCONTO_ITEM                       NUMBER;
   nPRECO_PRODUTO                       NUMBER;
   nVL_MINIMO_COND                      NUMBER;
   vcCD_PRAZO_DETERMINADO_ARQ           OPL_PEDIDO.CD_PRAZO_DETERMINADO_ARQ%TYPE;
   nPRAZO_CONDICAO_CLI                  NUMBER;
   nPRAZO_CONDICAO                      NUMBER;
   vcDM_STATUS_PEDIDO                   OPL_PEDIDO.DM_STATUS%TYPE;
  BEGIN
   
    DBMS_OUTPUT.PUT_LINE('PED : '|| nID_OPL_PEDIDO );
    
    BEGIN 
     SELECT DM_STATUS 
       INTO vcDM_STATUS_PEDIDO
       FROM OPL_PEDIDO 
      WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO;
    END;
    
    IF( vcDM_STATUS_PEDIDO NOT IN ('1','9') )THEN
      RETURN ;
    END IF ;
    
     
      ----------------------------------------
       -- 14	PEDIDO FORA DO HORARIO PERMITIDO
      -----------------------------------------
      IF SYSDATE >TO_DATE( TO_CHAR( SYSDATE, 'DD/MM/YYYY' ) || PCT_CTRL.F_CTRL_PARAMETRO('HR_MAX_PEDIDO_ELETRONICO'), 'DD/MM/YYYYHH24:MI:SS' ) THEN
           SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, NULL, 14, 0 );            
           RETURN; 
      END IF ;
       
      -------------------------------
      -- RECUPERA DADOS DO PEDIDO
      -------------------------------
      BEGIN 
        SELECT NR_CNPJ_CLIENTE , 
               DS_OBSERVACAO, 
               ID_PROJETO,
               OPL_PEDIDO.COND_PGTO_ARQ, 
               OPL_PEDIDO.CD_PRAZO_DETERMINADO_ARQ
          INTO nNR_CNPJ_CLIENTE, 
               vcDS_OBSERVACAO,
               nID_PROJETO,
               vcCOND_ARQ, 
               vcCD_PRAZO_DETERMINADO_ARQ
          FROM OPL_PEDIDO
         WHERE OPL_PEDIDO.ID_OPL_PEDIDO = nID_OPL_PEDIDO;
      EXCEPTION 
        WHEN NO_DATA_FOUND THEN
         RAISE_APPLICATION_ERROR( -20005, 'PED :'||nID_OPL_PEDIDO );
      END;
      ------------------------------
      -- VERIFICA SE CLIENTE EXITE
      ------------------------------
      BEGIN 
        SELECT ID_PESSOA 
          INTO NID_PESSOA 
          FROM GE_PESSOA 
         WHERE NR_CGC_CPF = nNR_CNPJ_CLIENTE; 
          
        UPDATE OPL_PEDIDO 
           SET ID_PESSOA      = NID_PESSOA 
         WHERE ID_OPL_PEDIDO  = NID_OPL_PEDIDO; 
          
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           -------------------------
           -- 2 CLIENTE INVALIDO
           -------------------------
           SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, NULL, 2 , 0);
           RETURN;
      END; 
       
      ------------------------
      -- 9 LAYOUT INVALIDO
      -------------------------
      IF( vcDS_OBSERVACAO IS NOT NULL ) THEN
        SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, NULL, 9, 0 );
        RETURN;
      END IF;
       
      ----------------------------------
      -- 13	CLIENTE BLOQUEADO
      -----------------------------------
      BEGIN
        PCT_CM.SP_CREDITO_CLIENTE( NID_PESSOA, 
                                    TRUNC( SYSDATE ), 
                                    VCDM_BLOQUEADO, 
                                    VCDS_MOTIVO_BLOQUEIO, 
                                    NVL_LIMITE_CREDITO, 
                                    NVL_TITULOS_ABERTO, 
                                    NVL_LIMITE_DISPONIVEL, 
                                    NVL_TITULOS_ATRASO
                                    );
         
         IF( VCDM_BLOQUEADO = 'S' ) THEN
         
           UPDATE OPL_PEDIDO
             SET DS_OBSERVACAO = VCDS_MOTIVO_BLOQUEIO
           WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO;
           
           SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, NULL, 13, 0 );
           RETURN;
         END IF;
         
       END;
    
      ---------------------------------------------
      --- CONVERTE COD. COND. INF. PARA COND.PEDIDO
      ---------------------------------------------
      
      -----------------------------------------
      ---> 1 PRAZO DETERMINADO
      ----------------------------------------- 
      IF( vcCD_PRAZO_DETERMINADO_ARQ IS NOT NULL ) THEN

        BEGIN 
          SELECT ID_CONDICAO_PGTO, 
                 NR_DIAS_PRAZO
            INTO nID_CONDICAO_PGTO, 
                 nPRAZO_CONDICAO
            FROM OPL_PROJETO_CONDICAO
           WHERE ID_PROJETO                 = NID_PROJETO 
             AND CD_CONDICAO_PGTO_PROJETO   = vcCD_PRAZO_DETERMINADO_ARQ;
        EXCEPTION 
          WHEN NO_DATA_FOUND THEN
            nID_CONDICAO_PGTO := NULL;
            nPRAZO_CONDICAO   := NULL;
        END;
        
        BEGIN   
          SELECT ID_CONDICAO_PGTO, 
                 NR_DIAS_PRAZO
            INTO nID_CONDICAO_PGTO_CLI, 
                 nPRAZO_CONDICAO_CLI
            FROM OPL_PROJETO_COND_CLIENTE 
           WHERE ID_PROJETO                 = NID_PROJETO
             AND CD_CONDICAO_PGTO_PROJETO   = vcCD_PRAZO_DETERMINADO_ARQ 
             AND ID_PESSOA                  = NID_PESSOA;
        EXCEPTION 
          WHEN NO_DATA_FOUND THEN
            nID_CONDICAO_PGTO_CLI := nID_CONDICAO_PGTO; 
            nPRAZO_CONDICAO_CLI   := nPRAZO_CONDICAO;
        END;
        
      END IF;

      -----------------------------------------
      ---> 2 CODIGO DA CONDICAO DO ARQUIVO
      ----------------------------------------- 
      IF ( nID_CONDICAO_PGTO IS NULL ) THEN 
      
         BEGIN   
          SELECT ID_CONDICAO_PGTO,
                 NR_DIAS_PRAZO
            INTO nID_CONDICAO_PGTO, 
                 nPRAZO_CONDICAO
            FROM OPL_PROJETO_CONDICAO 
           WHERE ID_PROJETO                 = NID_PROJETO
             AND CD_CONDICAO_PGTO_PROJETO   = vcCOND_ARQ ;
          EXCEPTION 
            WHEN NO_DATA_FOUND THEN
             ---------------------------
             -- 15 COND NAO ENCONTRADA
             ----------------------------
             --SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, NULL, 15, 0 );
             --RETURN;
             nID_CONDICAO_PGTO   := NULL;
             nPRAZO_CONDICAO     := NULL;
          END;
        
        ---------------------------------------------
        --- VERIFICA SE CLIENTE TEM COND. PROPRIA
        ---------------------------------------------     
         BEGIN   
          SELECT ID_CONDICAO_PGTO, 
                 NR_DIAS_PRAZO
            INTO nID_CONDICAO_PGTO_CLI, 
                 nPRAZO_CONDICAO_CLI
            FROM OPL_PROJETO_COND_CLIENTE 
           WHERE ID_PROJETO                 = NID_PROJETO
             AND CD_CONDICAO_PGTO_PROJETO   = vcCOND_ARQ 
             AND ID_PESSOA                  = NID_PESSOA;
          EXCEPTION 
            WHEN NO_DATA_FOUND THEN
              nID_CONDICAO_PGTO_CLI := nID_CONDICAO_PGTO;
              nPRAZO_CONDICAO_CLI   := nPRAZO_CONDICAO;
          END;
      
      END IF;
      
      IF( nID_CONDICAO_PGTO_CLI IS NULL ) THEN
        ---------------------------
        -- 15 COND NAO ENCONTRADA
        ----------------------------
        SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, NULL, 15, 0 );
        RETURN; 
      END IF;
      
      
      UPDATE OPL_PEDIDO
         SET ID_CONDICAO_PGTO = nID_CONDICAO_PGTO_CLI , 
             NR_DIAS_PRAZO    = nPRAZO_CONDICAO_CLI
       WHERE ID_OPL_PEDIDO    = NID_OPL_PEDIDO;
       
      BEGIN  
       SELECT VL_PEDIDO_MINIMO 
         INTO nVL_MINIMO_COND
         FROM CM_CONDICAO_PGTO
        WHERE ID_CONDICAO_PGTO   = nID_CONDICAO_PGTO_CLI;
        
        nVL_MINIMO_COND := NVL(nVL_MINIMO_COND, 0);
        
      EXCEPTION 
        WHEN NO_DATA_FOUND THEN
         nVL_MINIMO_COND :=  0;
      END;
      
-----------------------------
-- VERIFICA ITENS DO PEDIDO
----------------------------
       OPEN C_PEDIDOS;
         LOOP
           FETCH C_PEDIDOS INTO TRPEDIDOS ;
           EXIT WHEN C_PEDIDOS%NOTFOUND;
           
            --------------------------------
            -- VERIFICA SE PRODUTO :
            --    1 - EXITE
            --    2 - TEM SALDO SUFICIENTE
            --    3 - SE ESTA BLOQUEADO
            --------------------------------
             BEGIN              
               SELECT ES_PRODUTO.ID_PRODUTO, 
                      F_SALDO_FISICO_ALMOXARIFADO(ES_PRODUTO.ID_PRODUTO, 1, 1, TRUNC(SYSDATE)  ) SALDO,                      
                      ES_PRODUTO.DM_SITUACAO
                 INTO nID_PRODUTO, 
                      nQTD_Saldo,
                      vcSitProduto
                 FROM ES_PRODUTO, 
                      ES_PRODUTO_FARMACEUTICO
                WHERE ES_PRODUTO.ID_EAN13    = TRPEDIDOS.ID_EAN
                  AND ES_PRODUTO.DM_SITUACAO = 'A'
                  AND ES_PRODUTO.ID_PRODUTO  = ES_PRODUTO_FARMACEUTICO.ID_PRODUTO
                  AND ROWNUM = 1
                  ORDER BY  2    ;
                
                
                
               IF( nQTD_Saldo >= TRPEDIDOS.QTDE_PEDIDA )THEN
                 nQTD_Atendida := TRPEDIDOS.QTDE_PEDIDA ;
               END IF;
               
               IF( nQTD_Saldo < TRPEDIDOS.QTDE_PEDIDA ) AND ( nQTD_Saldo > 0 ) THEN
                 nQTD_Atendida :=  nQTD_Saldo;
               END IF;
               
               IF( nQTD_Saldo <= 0) THEN
                 nQTD_Atendida := 0;
               END IF;             
               
               -------------------------------------
               -- DESCONTO DADO PELO DISTRIBUIDOR 
               -------------------------------------
               DBMS_OUTPUT.PUT_LINE('nID_PRODUTO : '||nID_PRODUTO);
               nDESCONTO_ITEM := F_DESCONTO_PRODUTO( nID_PRODUTO , nID_PESSOA,TRUNC(SYSDATE), nID_CONDICAO_PGTO_CLI, nQTD_Atendida);
               
               nPRECO_PRODUTO := F_PRECO_VENDA_PRODUTO( nID_PRODUTO, SYSDATE ) ;
                
               DBMS_OUTPUT.PUT_LINE('nPRECO_PRODUTO : '||nPRECO_PRODUTO);
               
               UPDATE OPL_PEDIDO_ITEM
                  SET ID_PRODUTO     = nID_PRODUTO, 
                      VL_UNITARIO    = nPRECO_PRODUTO,
                      QTDE_ATENDIDA  = nQTD_Atendida, 
                      PERC_DESC_DIST = nDESCONTO_ITEM, 
                      QTDE_SALDO_DIA = nQTD_SALDO, 
                      VL_TOTAL       = ROUND( ( NVL(VL_UNITARIO,0) * NVL(QTDE_ATENDIDA,0)) * (1-( NVL(PERC_DESC_DIST,0) + NVL(PERC_DESC_ARQ,0) )/100),2)
                WHERE ID_EAN         = TRPEDIDOS.ID_EAN
                  AND NR_ITEM        = TRPEDIDOS.NR_ITEM 
                  AND ID_OPL_PEDIDO  = nID_OPL_PEDIDO;
              
              EXCEPTION 
                WHEN NO_DATA_FOUND THEN
                  -------------------------
                  -- 4	PRODUTO NAO ENCONTRADO
                  -------------------------
                  SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM, 4 , 0);
                  GOTO FIM_VALIDACAO;
              END;


              ------------------------------------------
              -- 10	CLIENTE SEM ALVARA / ALVARA VENCIDO
              ------------------------------------------
              IF( F_PERMITE_VENDA_CLIENTE( nID_PRODUTO , nID_PESSOA , TRUNC(SYSDATE) ) = 'N' )THEN
                SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM, 10, 0 );  
                GOTO FIM_VALIDACAO;
              END IF;

              ------------------------------------
              -- 6	PRODUTO SEM SALDO EM ESTOQUE
              ------------------------------------
              IF nQTD_Saldo <= 0 THEN              
                SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM, 6, nQTD_Atendida );  
                GOTO FIM_VALIDACAO;
              END IF;

              --------------------------------
              -- 7	SALDO INSUFICIENTE
              --------------------------------
              IF nQTD_SALDO < TRPEDIDOS.QTDE_PEDIDA AND nQTD_SALDO > 0 THEN
                SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM, 7, nQTD_Atendida );  
                GOTO FIM_VALIDACAO;
              END IF;
              

              --------------------------------
              -- 12	PRODUTO BLOQUEADO
              --------------------------------
              IF vcSitProduto NOT IN ('A') THEN
                SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM, 12 , 0 );  
                GOTO FIM_VALIDACAO;
              END IF;
         
         --------------------
         -- 1 ATENDIDO
         -------------------           
         SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM , 1, nQTD_Atendida );   
         
         <<FIM_VALIDACAO>>
         
         ----------------------------------------------
         -- O IF ABAIXO E APENAS PARA NAO DAR ERRO
         -- DEVIDO AO <<LABEL>>
         --------------------------------------------
         IF( 1 = 1 ) THEN
            NQTD_SALDO := NQTD_SALDO;
         END IF;

         COMMIT; 
         
       END LOOP;        
       CLOSE C_PEDIDOS;

       --------------------------------
       -- VALIDA CREDITO CLIENTE
       -------------------------------
       
       UPDATE OPL_PEDIDO_ITEM 
          SET VL_TOTAL      = ROUND( NVL( ( VL_UNITARIO * QTDE_ATENDIDA ) * ( 1- ( (PERC_DESC_ARQ + PERC_DESC_DIST) / 100 )),0),2)
        WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO;
       
       SELECT SUM( VL_TOTAL )
         INTO nTOTAL_PEDIDO                        
         FROM OPL_PEDIDO_ITEM 
        WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO;
         
        --------------------------------
        -- 03 	CLIENTE SEM LIMITE
        --------------------------------        
        IF ( nTOTAL_PEDIDO > NVL_LIMITE_DISPONIVEL ) THEN 
          
          DBMS_OUTPUT.PUT_LINE( 'nTOTAL_PEDIDO : '||nTOTAL_PEDIDO );
          DBMS_OUTPUT.PUT_LINE( 'NVL_LIMITE_DISPONIVEL : '||NVL_LIMITE_DISPONIVEL );
          
          SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, NULL , 3, 0 ); 
          RETURN;
        END IF;
        
        ---------------------------------
        -- 08 	NAO ALCANCOU VALOR MINIMO
        ---------------------------------
        IF ( nTOTAL_PEDIDO < nVL_MINIMO_COND ) AND ( nTOTAL_PEDIDO > 0)  THEN

          DBMS_OUTPUT.PUT_LINE( 'nTOTAL_PEDIDO : '||nTOTAL_PEDIDO );
          DBMS_OUTPUT.PUT_LINE( 'nVL_MINIMO_COND : '||nVL_MINIMO_COND );
          
          SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, NULL , 8, 0 ); 
          RETURN;
        END IF;
        
        
/*
--11  VERIFICAR PRODUTOS DO PROJETO
--08 	NAO ALCANCOU VALOR MINIMO
--10	CLIENTE SEM ALVARA / ALVARA VENCIDO
--03 	CLIENTE SEM LIMITE
--13	CLIENTE BLOQUEADO
--01	ATENDIDO
--02	CLIENTE INVALIDO
--4 	PRODUTO NAO ENCONTRADO
--6 	PRODUTO SEM SALDO EM ESTOQUE
--7   SALDO INSUFICIENTE
--9 	LAYOUT INCORRETO
--11	PRODUTO NAO CADASTRADO NO PROJETO
--12	PRODUTO BLOQUEADO
--14	PEDIDO FORA DO HORARIO PERMITIDO
*/
  -----------------------------------
  -- MUDA O STATUS PARA VALIDADO
  -----------------------------------     
    UPDATE OPL_PEDIDO
       SET DM_STATUS     = '2'
     WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO;


         
  COMMIT;       
  END;
  
  /*
     Procedimento......: SP_GERA_RETORNO_OPL
     Descricao.........: Gera retorno do item 
     Dt.Criacao/Autor..: ( 22/08/2011 ) - RODRIGO VIDAL
  */
 
  PROCEDURE SP_GERA_RETORNO_OPL( nID_OPL_PEDIDO            IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE, 
                                 nNR_ITEM                  IN     OPL_PEDIDO_ITEM.NR_ITEM%TYPE,
                                 nID_MOTIVO_RETORNO        IN     OPL_MOTIVO_RETORNO.ID_MOTIVO_RETORNO%TYPE,
                                 nQTDE_ATENDIDA            IN     OPL_PEDIDO_ITEM.QTDE_ATENDIDA%TYPE
                                 )  
  IS 
   NID_RETORNO    OPL_RETORNO.ID_RETORNO%TYPE;  
  BEGIN 

    SELECT OPL_MOTIVO_RETORNO.ID_RETORNO 
      INTO NID_RETORNO
      FROM OPL_MOTIVO_RETORNO
     WHERE OPL_MOTIVO_RETORNO.ID_MOTIVO_RETORNO    = NID_MOTIVO_RETORNO;
    
    DBMS_OUTPUT.PUT_LINE('ITEM -->> '|| NVL(nNR_ITEM,0) || ' : ' || nID_MOTIVO_RETORNO || ' : ' || nQTDE_ATENDIDA );
         
    IF NVL( nNR_ITEM, 0 ) = 0 THEN

      UPDATE OPL_PEDIDO_ITEM 
         SET ID_MOTIVO_RETORNO = NID_MOTIVO_RETORNO, 
             ID_RETORNO        = NID_RETORNO, 
             QTDE_ATENDIDA     = nQTDE_ATENDIDA
       WHERE ID_OPL_PEDIDO     = NID_OPL_PEDIDO ;

    ELSE 

      UPDATE OPL_PEDIDO_ITEM 
         SET ID_MOTIVO_RETORNO = NID_MOTIVO_RETORNO, 
             ID_RETORNO        = NID_RETORNO,
             QTDE_ATENDIDA     = nQTDE_ATENDIDA
       WHERE ID_OPL_PEDIDO     = NID_OPL_PEDIDO 
         AND NR_ITEM           = nNR_ITEM ; 

    END IF;

    UPDATE OPL_PEDIDO_ITEM
       SET VL_TOTAL       =ROUND( 
                                   ( NVL(VL_UNITARIO,0) * NVL(QTDE_ATENDIDA,0) ) * (1 -( NVL(PERC_DESC_DIST,0) + NVL(PERC_DESC_ARQ,0) )/100)
                                ,2)
     WHERE ID_OPL_PEDIDO  = NID_OPL_PEDIDO;
     
  END;

  /*
     Procedimento......: F_PERMITE_VENDA_CLIENTE
     Descricao.........: VERIFICA SE CLIENTE PODE COMPRAR DETERMINADO PRODUTO
     Dt.Criacao/Autor..: ( 23/08/2011 ) - RODRIGO VIDAL
  */
  FUNCTION F_PERMITE_VENDA_CLIENTE( nID_PRODUTO             IN     ES_PRODUTO.ID_PRODUTO%TYPE,
                                    nID_PESSOA              IN     GE_PESSOA.ID_PESSOA%TYPE, 
                                    dtREFERENCIA            IN     DATE
                                   ) RETURN NVARCHAR2
  IS
   nBLOQUEIO                NUMBER;
   nERSA                    NUMBER;
   vcRESULT                 VARCHAR2(1);
   vcDM_CLASSIFICACAO       ES_PRODUTO_FARMACEUTICO.DM_CLASSIFICACAO%TYPE;
   nID_SUBGRUPO             ES_PRODUTO.ID_SUBGRUPO%TYPE;
  BEGIN

  vcRESULT := 'S';
  vcDM_CLASSIFICACAO := '';
  
  BEGIN 
    SELECT ES_PRODUTO_FARMACEUTICO.DM_CLASSIFICACAO, 
           ES_PRODUTO.ID_SUBGRUPO
      INTO vcDM_CLASSIFICACAO,
           nID_SUBGRUPO     
      FROM ES_PRODUTO_FARMACEUTICO, 
           ES_PRODUTO
     WHERE ES_PRODUTO_FARMACEUTICO.ID_PRODUTO    = ES_PRODUTO.ID_PRODUTO 
       AND ES_PRODUTO.ID_PRODUTO                 = NID_PRODUTO;
  END; 

  DBMS_OUTPUT.PUT_LINE('PESSOA------>> '|| nID_PESSOA);
  DBMS_OUTPUT.PUT_LINE('CLASS ----->> '|| vcDM_CLASSIFICACAO);
  DBMS_OUTPUT.PUT_LINE('PRODUTO-->> '|| nID_PRODUTO );

  IF( vcDM_CLASSIFICACAO = '3' ) THEN
    RETURN vcRESULT; 
  END IF;
  
  ----------------------------
  -- BLOQUEIO DE MEDICAMENTO
  -------------------------
  BEGIN 
    SELECT COUNT(1) 
      INTO nBLOQUEIO
      FROM CM_BLOQUEIO_VENDA_MEDIC       
     WHERE DT_INICIO = ( SELECT MAX( BLOQ.DT_INICIO ) 
                           FROM CM_BLOQUEIO_VENDA_MEDIC BLOQ 
                          WHERE BLOQ.ID_PESSOA = CM_BLOQUEIO_VENDA_MEDIC.ID_PESSOA ) 
       AND ID_PESSOA = nID_PESSOA 
       AND dtREFERENCIA BETWEEN DT_INICIO AND NVL( DT_TERMINO, '31/12/2100');
  END;    

  DBMS_OUTPUT.PUT_LINE('nBLOQUEIO -->> '|| nBLOQUEIO);
    
  BEGIN    
    SELECT COUNT(1)
      INTO nERSA
      FROM CM_ALVARA_ERSA 
     WHERE CM_ALVARA_ERSA.DT_VENCIMENTO = ( SELECT MAX( ALVARA.DT_VENCIMENTO ) 
                                              FROM CM_ALVARA_ERSA ALVARA 
                                             WHERE ALVARA.ID_PESSOA = CM_ALVARA_ERSA.ID_PESSOA ) 
       AND ID_PESSOA = nID_PESSOA 
       AND CM_ALVARA_ERSA.DT_VENCIMENTO >= dtREFERENCIA;
  END;   
 
  DBMS_OUTPUT.PUT_LINE('nERSA -->> '|| nERSA);
   
  IF( nBLOQUEIO > 0 ) THEN
    vcRESULT := 'N';
  END IF;
  
  IF( nID_SUBGRUPO IN ( 2,3)  ) AND ( nERSA <= 0 ) THEN 
    vcRESULT := 'N';
  END IF ;
  
  DBMS_OUTPUT.PUT_LINE('PERMITIDO : -->> '|| vcRESULT);
  
  RETURN vcRESULT ;
  END;
 
  /*
     Procedimento......: F_DESCONTO_PRODUTO
     Descricao.........: PEGA DESCONTO DO PRODUTO
     Dt.Criacao/Autor..: ( 23/08/2011 ) - RODRIGO VIDAL
  */

  FUNCTION F_DESCONTO_PRODUTO    (  nID_PRODUTO             IN     ES_PRODUTO.ID_PRODUTO%TYPE,
                                    dtREFERENCIA            IN     DATE, 
                                    nID_CONDICAO_PGTO       IN     CM_CONDICAO_PGTO.ID_CONDICAO_PGTO%TYPE
                                   ) RETURN NUMBER
  IS 
   nDESCONTO               NUMBER;
  BEGIN 
    --- UTILIZA O CODIGO DA XXXXX PARA PEGAR OS DESCONTOS DO ESTADO DO CLIENTE
    RETURN F_DESCONTO_PRODUTO( nID_PRODUTO, 21493, dtREFERENCIA,nID_CONDICAO_PGTO, 1 );
  END;
  
  /*
     Procedimento......: F_DESCONTO_PRODUTO
     Descricao.........: PEGA DESCONTO DO PRODUTO
     Dt.Criacao/Autor..: ( 23/08/2011 ) - RODRIGO VIDAL
  */
 FUNCTION F_DESCONTO_PRODUTO     (  nID_PRODUTO             IN     ES_PRODUTO.ID_PRODUTO%TYPE,
                                    nID_PESSOA              IN     GE_PESSOA.ID_PESSOA%TYPE, 
                                    dtREFERENCIA            IN     DATE, 
                                    nID_CONDICAO_PGTO       IN     CM_CONDICAO_PGTO.ID_CONDICAO_PGTO%TYPE, 
                                    nQUANTIDADE             IN     NUMBER                                    
                                   ) RETURN NUMBER
  IS 
   nDESC_PRODUTO           NUMBER;
   nDESC_FORNECEDOR        NUMBER;
   nDESC_PRECO_FINAL       NUMBER;
   nDESC_UF                NUMBER;
   nDESCONTO_QTDE          NUMBER;
   
   nDESCONTO               NUMBER;
  BEGIN 
    nDESCONTO := 0;
  
  ------------------------
  -- DESCONTO PRODUTO
  -----------------------
   BEGIN  
     SELECT CM_DESCONTO_PRODUTO.PERC_DESCONTO_COML 
       INTO nDESC_PRODUTO
       FROM CM_DESCONTO_PRODUTO 
      WHERE ID_PRODUTO       = nID_PRODUTO 
        AND ID_CONDICAO_PGTO = nID_CONDICAO_PGTO;
    EXCEPTION 
      WHEN NO_DATA_FOUND THEN
        nDESC_PRODUTO := 0;
    END;

  ------------------------
  -- DESCONTO QUANTIDADE
  -----------------------
 
   BEGIN         
    SELECT PERC_DESCONTO_COML
      INTO nDESCONTO_QTDE
      FROM CM_DESCONTO_QTDE
     WHERE ID_PRODUTO = NID_PRODUTO 
       AND ID_CONDICAO_PGTO = nID_CONDICAO_PGTO
       AND nQUANTIDADE BETWEEN QTDE_INICIAL AND QTDE_FINAL;
    EXCEPTION 
      WHEN NO_DATA_FOUND THEN
        nDESCONTO_QTDE := 0;
    END;
   
  ------------------------
  -- DESCONTO FORNECEDOR
  -----------------------
    
   BEGIN 
     SELECT CM_DESCONTO_FORNEC.PERC_DESCONTO
       INTO nDESC_FORNECEDOR
       FROM CM_DESCONTO_FORNEC , 
            ES_PRODUTO_FARMACEUTICO
      WHERE CM_DESCONTO_FORNEC.ID_FORNECEDOR        = ES_PRODUTO_FARMACEUTICO.ID_PESSOA 
        AND CM_DESCONTO_FORNEC.ID_SEGMENTO_PRODUTO  = ES_PRODUTO_FARMACEUTICO.ID_SEGMENTO_PRODUTO        
        AND ES_PRODUTO_FARMACEUTICO.ID_PRODUTO      = nID_PRODUTO   
        AND CM_DESCONTO_FORNEC.ID_CONDICAO_PGTO     = nID_CONDICAO_PGTO ;
    EXCEPTION 
      WHEN NO_DATA_FOUND THEN
        nDESC_FORNECEDOR := 0;
    END;

  ------------------------
  -- DESCONTO PREÇO FINAL
  -----------------------
    IF( NVL(F_PRECO_VENDA_PRODUTO(nID_PRODUTO, dtREFERENCIA ),0) > 0 )THEN
    
      BEGIN
        SELECT ROUND( (1 -( CM_CONDICAO_PGTO_PRECO.PR_AVISTA/ F_PRECO_VENDA_PRODUTO(ID_PRODUTO, dtREFERENCIA ) ) )* 100,2) PERC_DESC
          INTO nDESC_PRECO_FINAL
          FROM CM_CONDICAO_PGTO_PRECO 
         WHERE CM_CONDICAO_PGTO_PRECO.ID_PRODUTO       = nID_PRODUTO 
           AND CM_CONDICAO_PGTO_PRECO.ID_CONDICAO_PGTO = nID_CONDICAO_PGTO; 
      EXCEPTION 
        WHEN NO_DATA_FOUND THEN
          nDESC_PRECO_FINAL := 0;
      END;
      
   ELSE 
     nDESC_PRECO_FINAL := 0;
   END IF;
  ------------------------
  -- DESCONTO UF
  -----------------------
    BEGIN 
      SELECT CM_DESCONTO_UF.PERC_DESCONTO
        INTO nDESC_UF
        FROM CM_DESCONTO_UF, 
             ES_PRODUTO_FARMACEUTICO, 
             GE_PESSOA, 
             GE_ENDERECO, 
             GE_MUNICIPIO
       WHERE CM_DESCONTO_UF.ID_SITUACAO_DESCONTO = ES_PRODUTO_FARMACEUTICO.ID_SITUACAO_DESCONTO
         AND GE_MUNICIPIO.ID_UF                  = CM_DESCONTO_UF.ID_UF
         AND GE_MUNICIPIO.ID_MUNICIPIO           = GE_ENDERECO.ID_MUNICIPIO
         AND GE_ENDERECO.ID_TIPO_ENDERECO        = PCT_CTRL.F_CTRL_PARAMETRO('TIPO_ENDERECO_COMERCIAL')
         AND GE_ENDERECO.ID_PESSOA               = GE_PESSOA.ID_PESSOA
         AND GE_PESSOA.ID_PESSOA                 = nID_PESSOA 
         AND ES_PRODUTO_FARMACEUTICO.ID_PRODUTO  = nID_PRODUTO 
         AND CM_DESCONTO_UF.ID_CONDICAO_PGTO     = nID_CONDICAO_PGTO ;
    EXCEPTION 
      WHEN NO_DATA_FOUND THEN
        nDESC_UF := 0;
    END;
   
   IF( nDESCONTO <  nDESCONTO_QTDE ) THEN
     nDESCONTO := nDESCONTO_QTDE ;
   END IF;
   
   IF( nDESCONTO <  nDESC_PRODUTO ) THEN
     nDESCONTO := nDESC_PRODUTO ;
   END IF;

   IF( nDESCONTO <  nDESC_FORNECEDOR ) THEN
     nDESCONTO := nDESC_FORNECEDOR ;
   END IF;

   IF( nDESCONTO <  nDESC_PRECO_FINAL ) THEN
     nDESCONTO := nDESC_PRECO_FINAL ;
   END IF;
   
   IF( nDESCONTO <  nDESC_UF ) THEN
     nDESCONTO := nDESC_UF ;
   END IF;
   
 
   DBMS_OUTPUT.PUT_LINE('nDESC_PRODUTO     -->'|| nDESC_PRODUTO );       
   DBMS_OUTPUT.PUT_LINE('nDESC_FORNECEDOR  -->'|| nDESC_FORNECEDOR );        
   DBMS_OUTPUT.PUT_LINE('nDESC_PRECO_FINAL -->'|| nDESC_PRECO_FINAL );      
   DBMS_OUTPUT.PUT_LINE('nDESC_UF          -->'|| nDESC_UF );         
   DBMS_OUTPUT.PUT_LINE('nDESCONTO : '|| nDESCONTO );         
    
    RETURN nDESCONTO;
  END;
                                     

  /*
     Procedimento......: SP_GERA_PEDIDO_TELEVENDA
     Descricao.........: TRANSFORMA OPL_PEDIDO EM CM_PEDIDO_TELEVENDA
     Dt.Criacao/Autor..: ( 24/08/2011 ) - RODRIGO VIDAL
  */
 PROCEDURE SP_GERA_PEDIDO_TELEVENDA ( nID_OPL_PEDIDO           IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE,
                                      nID_PEDIDO_TELEVENDA     OUT    CM_PEDIDO_TELEVENDA.ID_PEDIDO%TYPE) 
 IS
   CURSOR C_PEDIDOS IS 
       SELECT OPL_PEDIDO_ITEM.ID_PRODUTO, 
          OPL_PEDIDO_ITEM.QTDE_PEDIDA, 
          OPL_PEDIDO_ITEM.QTDE_ATENDIDA, 
          OPL_PEDIDO_ITEM.PERC_DESC_ARQ, 
          OPL_PEDIDO_ITEM.PERC_DESC_DIST,
          OPL_PEDIDO_ITEM.VL_UNITARIO,
          OPL_PEDIDO.ID_CONDICAO_PGTO, 
          OPL_PEDIDO.ID_PESSOA, 
          OPL_PROJETO.ID_USUARIO, 
          CM_CLIENTE.ID_VENDEDOR, 
          OPL_PEDIDO.ID_OPL_PEDIDO
     FROM OPL_PEDIDO, 
          OPL_PEDIDO_ITEM, 
          OPL_PROJETO, 
          CM_CLIENTE
    WHERE OPL_PEDIDO_ITEM.ID_OPL_PEDIDO    = OPL_PEDIDO.ID_OPL_PEDIDO
      AND OPL_PROJETO.ID_PROJETO           = OPL_PEDIDO.ID_PROJETO
      AND CM_CLIENTE.ID_PESSOA             = OPL_PEDIDO.ID_PESSOA
      AND OPL_PEDIDO.DM_STATUS             = '2'    
      AND OPL_PEDIDO.NR_PEDIDO_SISTEMA     IS NULL
      AND OPL_PEDIDO.ID_PESSOA             IS NOT NULL
      AND OPL_PEDIDO.ID_CONDICAO_PGTO      IS NOT NULL
      AND OPL_PEDIDO_ITEM.ID_PRODUTO       IS NOT NULL
      AND OPL_PEDIDO_ITEM.QTDE_ATENDIDA    > 0  
      AND OPL_PEDIDO.ID_OPL_PEDIDO         = NID_OPL_PEDIDO;    
  
   
   TRPEDIDOS             C_PEDIDOS%ROWTYPE;
   nNR_Item              NUMBER;
   dDT_Faturamento       DATE;
   nID_TIPO_VENDA        NUMBER;
   vcDM_STATUS_PEDIDO                   OPL_PEDIDO.DM_STATUS%TYPE;
  BEGIN
   
    DBMS_OUTPUT.PUT_LINE('PED : '|| nID_OPL_PEDIDO );
    
    BEGIN 
     SELECT DM_STATUS 
       INTO vcDM_STATUS_PEDIDO
       FROM OPL_PEDIDO 
      WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO;
    END;
    
    IF( vcDM_STATUS_PEDIDO NOT IN ('2') )THEN
      RETURN ;
    END IF ;
 
  nNR_Item := 0 ;
  dDT_Faturamento       := TRUNC(SYSDATE);


-----------------------------
-- VERIFICA ITENS DO PEDIDO
----------------------------
       OPEN C_PEDIDOS;
         LOOP
           FETCH C_PEDIDOS INTO TRPEDIDOS ;
           EXIT WHEN C_PEDIDOS%NOTFOUND;
            ----------------------------------
            -- INSERI O CABEÇALHO DO PEDIDO 
            ---------------------------------
            IF( nNR_Item = 0 )THEN

              SP_PROX_CODIGO('CM_PEDIDO_TELEVENDA',nID_PEDIDO_TELEVENDA);
              DBMS_OUTPUT.PUT_LINE('ID PEDIDO TELEVENDA -->> ' ||nID_PEDIDO_TELEVENDA );
              
              BEGIN
              INSERT INTO CM_PEDIDO_TELEVENDA ( ID_PEDIDO,
                                             DM_STATUS,
                                             DM_ORCAMENTO,
                                             DTHR_PEDIDO,
                                             ID_CONDICAO_PGTO,
                                             ID_PESSOA,
                                             ID_USUARIO,
                                             ID_EMPRESA,
                                             DM_ATIVO_PASSIVO,
                                             DM_BLOQUEADO,
                                             DM_VENDEDOR,
                                             ID_VENDEDOR,
                                             ID_PEDIDO_ANT,
                                             ID_TELEVENDA,
                                             ID_OPL_PEDIDO,
                                             VL_COMISSAO,
                                             DM_PROMOCAO,
                                             PRAZO,
                                             DT_FATURAMENTO,
                                             NR_ORDEM_PRENOTA,
                                             DM_TIPO_PEDIDO_ANT, 
                                             ID_TIPO_VENDA
                                           )
                                    VALUES ( nID_PEDIDO_TELEVENDA,
                                             '1',
                                             'N',
                                             SYSDATE,
                                             trPEDIDOS.ID_CONDICAO_PGTO,
                                             trPEDIDOS.ID_PESSOA,
                                             trPEDIDOS.ID_USUARIO,
                                             1,
                                             'P',
                                             'N',
                                             'N',
                                             trPEDIDOS.ID_VENDEDOR,
                                             NULL,
                                             1,
                                             trPEDIDOS.ID_OPL_PEDIDO,
                                             0,
                                             'S',
                                             NULL,
                                             dDT_Faturamento,
                                             NULL,
                                             NULL, 
                                             0
                                           ) ;
              DBMS_OUTPUT.PUT_LINE('INSERIDO');
       
              END;                             
             END IF;
             
             nNR_ITEM  := nNR_ITEM + 1 ;
             ------------
             -- ITENS
             ------------
              INSERT INTO CM_PEDIDO_TELEVENDA_ITEM ( ID_PEDIDO,
                                                    NR_ITEM,
                                                    ID_PRODUTO,
                                                    QUANTIDADE,
                                                    VL_UNITARIO,
                                                    VL_TOTAL,
                                                    PERC_DESCONTO,
                                                    PERC_DESCONTO_CRED,
                                                    PERC_REPASSE,
                                                    PERC_COMISSAO,
                                                    PRAZO,
                                                    PERC_DESCONTO_COML,
                                                    VL_CUSTO,
                                                    VL_AVISTA,
                                                    VL_APRAZO,
                                                    DM_PROMOCAO,
                                                    PERC_DESCONTO_CONDICAO,
                                                    PERC_DESCONTO_ELETRONICO
                                                  )
                                            VALUES ( nID_Pedido_Televenda,
                                                    nNR_Item,
                                                    trPEDIDOS.ID_PRODUTO,
                                                    trPEDIDOS.QTDE_ATENDIDA, 
                                                    trPEDIDOS.VL_UNITARIO, 
                                                    trPEDIDOS.QTDE_ATENDIDA * trPEDIDOS.VL_UNITARIO,
                                                    trPEDIDOS.PERC_DESC_DIST,
                                                    0,
                                                    0,
                                                    0,
                                                    0,
                                                    trPEDIDOS.PERC_DESC_DIST,
                                                    0,
                                                    trPEDIDOS.VL_UNITARIO,
                                                    trPEDIDOS.VL_UNITARIO,
                                                    'S',                                                    
                                                    trPEDIDOS.PERC_DESC_ARQ,
                                                    trPEDIDOS.PERC_DESC_DIST
                                                  ) ;
                                                  
         DBMS_OUTPUT.PUT_LINE('ITEM --> '||nNR_Item );                                                  
         END LOOP;                                                  
       CLOSE C_PEDIDOS;      
             
       IF ( NVL(nID_PEDIDO_TELEVENDA,0) > 0 ) THEN
         UPDATE OPL_PEDIDO
            SET NR_PEDIDO_SISTEMA = nID_PEDIDO_TELEVENDA, 
                DM_STATUS         = '3'
          WHERE ID_OPL_PEDIDO     = nID_OPL_PEDIDO;
       ELSE
         UPDATE OPL_PEDIDO
            SET DM_STATUS        = '4'
          WHERE ID_OPL_PEDIDO    = nID_OPL_PEDIDO
            AND NR_PEDIDO_SISTEMA IS NOT NULL ;
       END IF; 
    
      
      
 END;

  /*
     Procedimento......: SP_PROCESSA_PEDIDO_OPL
     Descricao.........: INTERFACE A SER CHAMADA 
     Dt.Criacao/Autor..: ( 24/08/2011 ) - RODRIGO VIDAL
  */
  
 PROCEDURE SP_PROCESSA_PEDIDO_OPL ( NID_OPL_PEDIDO               IN OPL_PEDIDO.ID_OPL_PEDIDO%TYPE )
 IS
  nID_PEDIDO_TELEVENDA     CM_PEDIDO_TELEVENDA.ID_PEDIDO%TYPE;
  nID_Pedido_Ant           NUMBER;
 BEGIN
   ----------------------
   -- VALIDACAO INICIAL 
   ----------------------
   SP_VALIDACAO_INICIAL_OPL( NID_OPL_PEDIDO ) ;   
   
   -------------------
   -- GERA PEDIDO
   ------------------
   SP_GERA_PEDIDO_TELEVENDA( NID_OPL_PEDIDO , nID_PEDIDO_TELEVENDA );

   -------------------
   -- FATURA PEDIDO
   -------------------
   IF( NVL(nID_PEDIDO_TELEVENDA,0) > 0 ) THEN
     PCT_CM.SP_FATURA_TELEVENDA( nID_PEDIDO_TELEVENDA, 'VENDA', 'N', 'S', nID_Pedido_Ant ) ;
     
     UPDATE OPL_PEDIDO
        SET DM_STATUS     = '4'
      WHERE DM_STATUS     = '3'
        AND ID_OPL_PEDIDO = NID_OPL_PEDIDO;
     
        
   END IF;     
   
   --------------------
   -- VALIDACAO FINAL
   --------------------
   SP_VALIDACAO_FINAL_OPL( NID_OPL_PEDIDO );
   SP_VALIDACAO_FINAL_CABECALHO( NID_OPL_PEDIDO ); 
   
   -------------------------------------------
   -- VERIFICA SE TEM ALGUM EM VALIDACAO AINDA 
   --  E MUDA PARA STATUS 9 NAO FATURADO
   --------------------------------------------
   UPDATE OPL_PEDIDO 
      SET DM_STATUS     = '9'
    WHERE DM_STATUS     IN ('1','2','3')
      AND ID_OPL_PEDIDO = NID_OPL_PEDIDO;
   
   COMMIT;
   
 END;
 
 
   /*
     Procedimento......: SP_VALIDACAO_FINAL_OPL
     Descricao.........: FAZ A VALIDACAO FINAL DO PEDIDO
     Dt.Criacao/Autor..: ( 25/08/2011 ) - RODRIGO VIDAL
  */
  PROCEDURE SP_VALIDACAO_FINAL_OPL( nID_OPL_PEDIDO           IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE) 
     
  IS 
   CURSOR C_PEDIDOS IS 
      SELECT OPL_PEDIDO.ID_OPL_PEDIDO,
             OPL_PEDIDO.ID_PESSOA,
             OPL_PEDIDO.NR_PEDIDO_SISTEMA,
             OPL_PEDIDO_ITEM.ID_PRODUTO,
             OPL_PEDIDO_ITEM.ID_EAN, 
             OPL_PEDIDO_ITEM.QTDE_PEDIDA,
             OPL_PEDIDO_ITEM.QTDE_ATENDIDA,
             OPL_PEDIDO_ITEM.NR_ITEM
        FROM OPL_PEDIDO, 
             OPL_PEDIDO_ITEM 
       WHERE OPL_PEDIDO_ITEM.ID_OPL_PEDIDO  = OPL_PEDIDO.ID_OPL_PEDIDO
         AND OPL_PEDIDO.DM_STATUS           IN( '4','5' )
         AND OPL_PEDIDO_ITEM.QTDE_ATENDIDA  > 0
         AND OPL_PEDIDO.ID_OPL_PEDIDO       = nID_OPL_PEDIDO
         ORDER BY NR_ITEM ;           
  
   TRPedidos                            C_PEDIDOS%ROWTYPE;
   nQTDE_FATURADA                       NUMBER;
   vcDM_STATUS_PEDIDO                   OPL_PEDIDO.DM_STATUS%TYPE;
   nAtendido                NUMBER;
   nParcial                 NUMBER;
   nNaoAtendido             NUMBER;
   nItens                   NUMBER;
   vcDM_Retorno             VARCHAR2(1);
  BEGIN
   
    DBMS_OUTPUT.PUT_LINE('PED : '|| nID_OPL_PEDIDO );
    
    BEGIN 
     SELECT DM_STATUS 
       INTO vcDM_STATUS_PEDIDO
       FROM OPL_PEDIDO 
      WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO;
    END;
    
    IF( vcDM_STATUS_PEDIDO NOT IN ('4','5') )THEN
      RETURN ;
    END IF ;
  
    NQTDE_FATURADA := 0;
-----------------------------
-- VERIFICA ITENS DO PEDIDO
----------------------------
       OPEN C_PEDIDOS;
         LOOP
           FETCH C_PEDIDOS INTO TRPEDIDOS ;
           EXIT WHEN C_PEDIDOS%NOTFOUND;

             BEGIN 
               SELECT QTDE 
                INTO nQTDE_FATURADA
                FROM CM_ITEM, 
                     CM_MOVIMENTO
               WHERE CM_ITEM.ID_MOVIMENTO   = CM_MOVIMENTO.ID_MOVIMENTO
                 AND CM_MOVIMENTO.ID_PEDIDO = trPEDIDOS.NR_PEDIDO_SISTEMA
                 AND CM_ITEM.ID_PRODUTO     = trPEDIDOS.ID_PRODUTO;
               
               --------------------------------
               -- 1	ATENDIDO
               --------------------------------
               IF( nQTDE_FATURADA >= TRPEDIDOS.QTDE_PEDIDA )THEN                 
                 SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM, 1 , nQTDE_FATURADA);
               END IF;
               
               --------------------------------
               -- 7	SALDO INSUFICIENTE
               --------------------------------
               IF( nQTDE_FATURADA < TRPEDIDOS.QTDE_PEDIDA )  THEN
                 SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM, 7, nQTDE_FATURADA );  
               END IF;
               
             EXCEPTION 
               WHEN NO_DATA_FOUND THEN
                  ---------------------------
                  -- 16	MOTIVO DESCONHECIDO
                  ---------------------------
                  SP_GERA_RETORNO_OPL(nID_OPL_PEDIDO, TRPEDIDOS.NR_ITEM, 16 , 0);
             END;  
            COMMIT; 
         END LOOP;        
       CLOSE C_PEDIDOS;

  -----------------------------------
  -- MUDA O STATUS PARA 
  --   | 5 | VALIDOU AS FALTAS
  -----------------------------------     
    UPDATE OPL_PEDIDO
       SET DM_STATUS     = '5', 
           DM_RETORNO    = vcDM_Retorno
     WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO
       AND DM_STATUS     IN ('4','5');
         
  COMMIT; 

  
END; -- FIM PROCEDURE

PROCEDURE SP_OPL
IS
BEGIN 
 --------------------------------------
 -- PROCESSA PEDIDOS DAS 9 ATE AS 20:30
 -- DE SEGUNDA A SEXTA
 --------------------------------------

  IF ( SYSDATE > TO_DATE( TO_CHAR( TRUNC(SYSDATE), 'DD/MM/YYYY' ) || '20:30', 'DD/MM/YYYYHH24:MI' ) ) OR  
     ( SYSDATE < TO_DATE( TO_CHAR( TRUNC(SYSDATE), 'DD/MM/YYYY' ) || '08:00', 'DD/MM/YYYYHH24:MI' ) ) OR 
     ( TO_CHAR( SYSDATE , 'D' ) IN ( '7', '1' )                                                     ) THEN    
    RETURN;
  END IF ;

    

  INSERT INTO OPL_CMD( ID_CMD, DS_CMD, VL_CMD ) 
     SELECT F_PROX_CODIGO('OPL_CMD'), 
            DECODE( ID_TIPO_OL,8,'PROCESSAR COTACOES','PROCESSAR PEDIDOS'), 
            ID_PROJETO
        FROM OPL_PROJETO 
       WHERE DM_SITUACAO = 'A';
 
       
--------------------------------------------------------------------------------
-- ATUALIZA COMO FINALIZADO LAYOUTS QUE NAO POSSUEM TIPO 3 // NOTA FISCAL
--------------------------------------------------------------------------------
  UPDATE OPL_PEDIDO 
     SET DM_STATUS = '8' 
   WHERE OPL_PEDIDO.ID_PROJETO IN ( 
                            SELECT OPL_PROJETO.ID_PROJETO 
                              FROM OPL_PROJETO
                              WHERE NOT EXISTS (  SELECT OPL_LAYOUT.ID_GRP_LAYOUT 
                                                    FROM OPL_LAYOUT 
                                                   WHERE OPL_LAYOUT.ID_GRP_LAYOUT = OPL_PROJETO.ID_GRP_LAYOUT
                                                     AND OPL_LAYOUT.ID_TIPO_LAYOUT = 3
                                                 )
                          )
     AND OPL_PEDIDO.DM_STATUS = '5'
     AND EXISTS (   SELECT CM_MOVIMENTO.ID_MOVIMENTO 
                      FROM CM_MOVIMENTO 
                     WHERE CM_MOVIMENTO.ID_PEDIDO = OPL_PEDIDO.NR_PEDIDO_SISTEMA
                       AND CM_MOVIMENTO.NR_DOCUMENTO > 0 
                       AND CM_MOVIMENTO.DM_STATUS    = 3 );  
                       
                       
                       

  INSERT INTO OPL_CMD( ID_CMD, DS_CMD, VL_CMD ) 
    SELECT F_PROX_CODIGO('OPL_CMD'), 
           'GERAR RETORNO NOTAFISCAL',          
           OPL_PEDIDO.ID_OPL_PEDIDO
      FROM OPL_PEDIDO, 
           CM_MOVIMENTO 
     WHERE CM_MOVIMENTO.ID_PEDIDO     = OPL_PEDIDO.NR_PEDIDO_SISTEMA
       AND CM_MOVIMENTO.NR_DOCUMENTO  > 0
       AND CM_MOVIMENTO.DM_STATUS     = '3'
       AND OPL_PEDIDO.DM_STATUS      IN ('5')
       AND NOT EXISTS ( SELECT * FROM OPL_CMD WHERE DS_CMD='GERAR RETORNO NOTAFISCAL' AND VL_CMD = OPL_PEDIDO.ID_OPL_PEDIDO );
 
  COMMIT;

 
END;

PROCEDURE SP_VALIDACAO_FINAL_CABECALHO(  nID_OPL_PEDIDO       IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE)
IS 
   nAtendido                NUMBER;
   nParcial                 NUMBER;
   nNaoAtendido             NUMBER;
   nItens                   NUMBER;
   vcDM_Retorno             VARCHAR2(1);
BEGIN 
  -----------------------------------
  -- PREENCHE O CAMPO DM_RETORNO
  -- 
  -----------------------------------     

        SELECT ( SELECT COUNT(*) 
                   FROM OPL_PEDIDO_ITEM
                  WHERE ID_OPL_PEDIDO = NID_OPL_PEDIDO
                    AND ID_RETORNO    = 1 -- ATENDIDO
                    ) ATENDIDO,
               ( SELECT COUNT(*) 
                   FROM OPL_PEDIDO_ITEM
                  WHERE ID_OPL_PEDIDO = NID_OPL_PEDIDO
                    AND ID_RETORNO    = 2 -- PARCIAL
                    ) PARCIAL,
               ( SELECT COUNT(*) 
                   FROM OPL_PEDIDO_ITEM
                  WHERE ID_OPL_PEDIDO = NID_OPL_PEDIDO
                    AND ID_RETORNO    = 3 --NAO ATENDIDO
                    ) NAO_ATENDIDO,
               ( SELECT COUNT(*) 
                   FROM OPL_PEDIDO_ITEM
                  WHERE ID_OPL_PEDIDO = NID_OPL_PEDIDO
                    ) ITENS
        INTO 
              nAtendido    ,  
              nParcial     ,  
              nNaoAtendido ,  
              nItens          
        FROM DUAL  ;          

  DBMS_OUTPUT.PUT_LINE('ATENDIDO : '|| nAtendido );
  DBMS_OUTPUT.PUT_LINE('PARCIAL  : '|| nParcial );
  DBMS_OUTPUT.PUT_LINE('N ATENDO : '|| nNaoAtendido );
  DBMS_OUTPUT.PUT_LINE('N ITENS  : '|| nItens );
         

  IF( nAtendido = nItens )THEN
    vcDM_Retorno :='1';
  END IF;
  
  IF( nNaoAtendido = nItens )THEN
    vcDM_Retorno :='3';
  END IF;
  
  IF( 
     (nParcial > 0) OR 
     ( nNaoAtendido > 0 AND nNaoAtendido < nItens) 
     )THEN
    vcDM_Retorno :='2';
  END IF;

  DBMS_OUTPUT.PUT_LINE('vcDM_Retorno: '|| vcDM_Retorno );
  
    UPDATE OPL_PEDIDO
       SET DM_RETORNO    = vcDM_Retorno
     WHERE ID_OPL_PEDIDO = nID_OPL_PEDIDO;
 
END;
                  

FUNCTION F_CONDICAO_PERMITE_PRODUTO( nID_Produto         IN ES_PRODUTO.ID_PRODUTO%TYPE, 
                                     nID_Condicao_Pgto   IN CM_CONDICAO_PGTO.ID_CONDICAO_PGTO%TYPE , 
                                     nID_Pessoa          IN GE_PESSOA.ID_PESSOA%TYPE, 
                                     DT_Referencia       IN DATE
                                   )RETURN NVARCHAR2
IS
  nCondicaoPromocao  NUMBER;
  nDescontoProduto   NUMBER;
  vcRetorno          NVARCHAR2(2);
  vcDM_Ativo         ES_PRODUTO.DM_SITUACAO%TYPE;       
BEGIN 
  BEGIN 
    SELECT COUNT(*) 
      INTO nCondicaoPromocao
      FROM CM_CONDICAO_PGTO
     WHERE CM_CONDICAO_PGTO.ID_CONDICAO_PGTO        = nID_Condicao_Pgto
       AND CM_CONDICAO_PGTO.DM_CHECAR_PRODUTO_PROMO = 'S'
       AND CM_CONDICAO_PGTO.DM_PROMOCAO             = 'S';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      nCondicaoPromocao := 0 ;
  END;

  BEGIN  
    SELECT DM_SITUACAO 
      INTO vcDM_ATIVO
      FROM ES_PRODUTO 
     WHERE ID_PRODUTO  = nID_Produto;
  EXCEPTION 
    WHEN NO_DATA_FOUND THEN
      vcDM_ATIVO := 'I'; 
  END; 

  nDescontoProduto := PCT_OPL.F_DESCONTO_PRODUTO( nID_Produto, nID_Pessoa, DT_Referencia, nID_Condicao_Pgto,1 ) ;
  
  IF( nCondicaoPromocao > 0 AND nDescontoProduto <= 0) THEN
    vcRetorno := 'N';
  ELSE
    vcRetorno := 'S';
  END IF;
  
  IF( F_SALDO_FISICO_ALMOXARIFADO(nID_Produto,1, 1, DT_Referencia ) <= 0 )THEN
     vcRetorno := 'E';
  END IF;
 
  IF( vcDM_ATIVO IN ('I','F') )THEN
     vcRetorno := 'I';
  END IF;
 
  
  RETURN vcRetorno;

END;


  
  
END PCT_OPL;