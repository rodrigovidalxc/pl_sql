-- Alterado em 11/10/2012 11:53:24
CREATE OR REPLACE 
PACKAGE            "PCT_OPL" AS

  PROCEDURE SP_VALIDACAO_INICIAL_OPL ( nID_OPL_PEDIDO            IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE
                                     );
                                    
  
  PROCEDURE SP_GERA_RETORNO_OPL      ( nID_OPL_PEDIDO            IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE, 
                                       nNR_ITEM                  IN     OPL_PEDIDO_ITEM.NR_ITEM%TYPE,
                                       nID_MOTIVO_RETORNO        IN     OPL_MOTIVO_RETORNO.ID_MOTIVO_RETORNO%TYPE, 
                                       nQTDE_ATENDIDA            IN     OPL_PEDIDO_ITEM.QTDE_ATENDIDA%TYPE
                                      );
                                  
  FUNCTION F_PERMITE_VENDA_CLIENTE    ( nID_PRODUTO             IN     ES_PRODUTO.ID_PRODUTO%TYPE,
                                        nID_PESSOA              IN     GE_PESSOA.ID_PESSOA%TYPE, 
                                        dtREFERENCIA            IN     DATE
                                      ) RETURN NVARCHAR2;

  FUNCTION F_DESCONTO_PRODUTO     (  nID_PRODUTO             IN     ES_PRODUTO.ID_PRODUTO%TYPE,
                                     nID_PESSOA              IN     GE_PESSOA.ID_PESSOA%TYPE, 
                                     dtREFERENCIA            IN     DATE, 
                                     nID_CONDICAO_PGTO       IN     CM_CONDICAO_PGTO.ID_CONDICAO_PGTO%TYPE, 
                                     nQUANTIDADE             IN     NUMBER
                                   ) RETURN NUMBER;

  FUNCTION F_DESCONTO_PRODUTO         ( nID_PRODUTO             IN     ES_PRODUTO.ID_PRODUTO%TYPE,
                                        dtREFERENCIA            IN     DATE, 
                                        nID_CONDICAO_PGTO       IN     CM_CONDICAO_PGTO.ID_CONDICAO_PGTO%TYPE
                                      ) RETURN NUMBER;

  PROCEDURE SP_GERA_PEDIDO_TELEVENDA ( nID_OPL_PEDIDO           IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE,
                                       nID_PEDIDO_TELEVENDA     OUT    CM_PEDIDO_TELEVENDA.ID_PEDIDO%TYPE) ;
 
  PROCEDURE SP_PROCESSA_PEDIDO_OPL   ( NID_OPL_PEDIDO           IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE );
  
  PROCEDURE SP_VALIDACAO_FINAL_OPL   ( nID_OPL_PEDIDO           IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE) ;
  
  PROCEDURE SP_OPL;
  
  PROCEDURE SP_VALIDACAO_FINAL_CABECALHO(  nID_OPL_PEDIDO       IN     OPL_PEDIDO.ID_OPL_PEDIDO%TYPE) ;
            
  FUNCTION F_CONDICAO_PERMITE_PRODUTO( nID_Produto         IN ES_PRODUTO.ID_PRODUTO%TYPE, 
                                       nID_Condicao_Pgto   IN CM_CONDICAO_PGTO.ID_CONDICAO_PGTO%TYPE , 
                                       nID_Pessoa          IN GE_PESSOA.ID_PESSOA%TYPE, 
                                       DT_Referencia       IN DATE
                                     )RETURN NVARCHAR2 ;
                                     
  
END PCT_OPL;
