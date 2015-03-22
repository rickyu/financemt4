//+------------------------------------------------------------------+
//|                                                        Order.mqh |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
 
 enum EnumOrderDirection
 {
     ORDER_BUY = 1,
     ORDER_SELL 
 };
 struct COrder  
 {
 public:
      int ticket;
      string symbol;
      int type;
      double lots;
      double open_price;
      double close_price;
      datetime close_time;
 public:
      EnumOrderDirection GetDirection() const {
          return (OP_BUYLIMIT == type || OP_BUY == type || OP_BUYSTOP == type) ? ORDER_BUY : ORDER_SELL; 
      }
      bool IsDirectionSame(const COrder& o) const {
          return o.GetDirection() == GetDirection();
      }
      bool IsBuy() const { return GetDirection() == ORDER_BUY;}    
       bool IsSell() const { return GetDirection() == ORDER_SELL;}       
      bool IsClosed() { return close_time != 0;}
      bool IsLost();
      bool IsPending() const {
          return type == OP_BUYLIMIT || type == OP_SELLLIMIT || type == OP_SELLSTOP || type == OP_BUYSTOP;
      }
  public:
      static EnumOrderDirection GetDirection(int t)  {
          return (OP_BUYLIMIT == t || OP_BUY == t || OP_BUYSTOP == t) ? ORDER_BUY : ORDER_SELL; 
      }
 };

  
  
  class COrderManager
  {
  public:
  
      int SelectOrders(EnumOrderDirection direction, int magic, COrder& orders[]);
      
      // @param long_or_short: 1:多头，2，空头(sell), 0： 全部
      // @return : 返回的订单个数, <0 表示出错.
      int SelectOrders(string symbol, EnumOrderDirection direction, int magic,   COrder& orders[]);
      int SelectOrdersByBreakthrough(string symbol, int breakthrough_id, COrder &orders[]);
      int SelectOrders(const string symbol, COrder& orders[]);
      // 参考http://book.mql4.com/appendix/limits 自动做价格微调

        int OpenOrder(const string symbol, 
                             int cmd, 
                             double volume, 
                             double price, 
                             int slippage, 
                             double stoploss, 
                             int magic,
                             double takeprofit = 0, 
                             string comment=NULL);
      int CloseOrder(int ticket,double price);
      int CloseOrders(const string symbol, bool up, double price, int slippage);
      
  
      int Count();
      int Sum();
  private:
      void FillOrder(COrder& order);
      
  };
  
bool COrder::IsLost() 
{
    if (IsClosed()) {
         if (type == OP_BUY && open_price > close_price) {
             return true;
         }
         if (type == OP_SELL && open_price < close_price) {
             return true;
         }
     }
     return false; 
}
int COrderManager::SelectOrders(EnumOrderDirection direction, int magic, COrder& orders[])
{
    int count = 0;
    
    if (ArrayResize(orders, OrdersTotal()+100) < 0) {
        return -__LINE__;
    }
    for (int i = 0; i < OrdersTotal(); ++i) {
        OrderSelect(i, SELECT_BY_POS);
        if (OrderMagicNumber() == magic
            && COrder::GetDirection(OrderType()) == direction) {
            FillOrder(orders[count++]);
        }
    
    }
    return count;
    
    
}
  int COrderManager::SelectOrders(string symbol, EnumOrderDirection direction, int magic,  COrder &orders[])
  {
      int count = 0;
      if (ArrayResize(orders, OrdersTotal(), OrdersHistoryTotal() + OrdersTotal()) < 0) {
          return -__LINE__;
      }
      for (int i=0; i<OrdersTotal(); ++i) {
          OrderSelect(i, SELECT_BY_POS);
          if (OrderSymbol() == symbol 
              && OrderMagicNumber() == magic 
              && COrder::GetDirection(OrderType()) == direction) {
                FillOrder(orders[count++]);              
          }
      }
      return count;
  }
  
  int COrderManager::SelectOrders(const string symbol, COrder &orders[])
  {
      int count = 0;
      if (ArrayResize(orders, OrdersTotal(), OrdersHistoryTotal() + OrdersTotal()) < 0) {
          return -__LINE__;
      }
      for (int i=0; i<OrdersTotal(); ++i) {
          OrderSelect(i, SELECT_BY_POS);
          if (OrderSymbol() == symbol) {
              FillOrder(orders[count++]);       
          }
      }
      return count;
  }
  
  
  int COrderManager::SelectOrdersByBreakthrough(string symbol,  int breakthrough_id, COrder &orders[])
  {
      int count = 0;
      if (ArrayResize(orders, OrdersTotal()+ OrdersHistoryTotal(), OrdersHistoryTotal() + OrdersTotal()) < 0) {
          return -__LINE__;
      }
      for (int i=0; i<OrdersTotal(); ++i) {
          OrderSelect(i, SELECT_BY_POS);
          if (OrderSymbol() == symbol) {
            if ( OrderMagicNumber() == breakthrough_id) {
                FillOrder(orders[count++]);

            }          
          }
      }
      for (int i=0; i<OrdersHistoryTotal(); ++i) {
          OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
          if (OrderSymbol() == symbol) {
             if (OrderMagicNumber() == breakthrough_id) {
                FillOrder(orders[count++]);               
             }
          }
      }
      return count;
      
  }
  void COrderManager::FillOrder(COrder& order)
  {
    order.ticket = OrderTicket();
    order.lots = OrderLots();
    order.open_price = OrderOpenPrice();
    order.type = OrderType();
    order.symbol = OrderSymbol();
  }
  
  int COrderManager::OpenOrder(
                                const string symbol, 
                             int cmd, 
                             double volume, 
                             double price, 
                             int slippage, 
                             double stoploss, 
                             int magic, 
                             double takeprofit,                          
                             string comment)
  {
      int digits = MarketInfo(symbol, MODE_DIGITS);
      stoploss = NormalizeDouble(stoploss, digits); 
      takeprofit = NormalizeDouble(takeprofit, digits);   
      price = NormalizeDouble(price, digits);
      int ticket =  OrderSend(symbol, cmd, volume, price, slippage, stoploss, takeprofit, comment, magic);
      if (ticket > 0) {
          Print("OpenOrder succeed, symbol=", symbol, 
                ", cmd=", cmd, ", volume=", volume, ", pricke=",price, ", stoploss=", stoploss, ",ticket=", ticket);
      } else {
          Print("OpenOrder fail, symbol=", symbol, 
                ", cmd=", cmd, ", volume=", volume, ", pricke=",price, ", stoploss=", stoploss, ",error=", GetLastError());
      }
      return ticket;
  }
  


  
 int COrderManager::CloseOrders(const string symbol, bool up, double price, int slippage)
 {
     int type = up ? OP_BUY : OP_SELL;
     int pending_type = up? OP_BUYLIMIT : OP_SELLLIMIT;
     for (int i=0; i<OrdersTotal(); ++i) {
         OrderSelect(i, SELECT_BY_POS);
         if (OrderSymbol() != symbol) {
             continue;
         }
         if (OrderType() == type) {
            if (OrderClose(OrderTicket(), OrderLots(), price, slippage)) {
                Print("takeprofit:succeed close order:ticket=", OrderTicket(), ",type=", OrderType(), ",open_price=", OrderOpenPrice(), ", close_price=", OrderClosePrice());
            } else {
                Print("takeprofit:failed close order:ticket=", OrderTicket(), ",type=", OrderType(), ",open_price=", OrderOpenPrice());
            }             
         
         }
         if (OrderType() == pending_type) {
             OrderDelete(OrderTicket());
         }
   }
   return 0;
  }