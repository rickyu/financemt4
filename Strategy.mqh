//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
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
#include <Object.mqh>
#include "Breakthrough.mqh"
#include "Order.mqh"

class CStrategy : public CObject
{
public:

};
struct Tick
{
    datetime timestamp;
    double ask;
    double bid;
    string symbol;
};

struct PeriodInfo
{
    datetime begin;
    datetime end;
    
};
class CPositionManager
{
public:
   void Update(bool force = false);
};

struct System1Config
{
    string symbol;
    int timeframe;
    int slippage;
    double fund; // 资金数量
    double stop_loss_times_n; // 止损差值,书上是2
    double order_price_range_times_n; // 下单价和突破价之间的差距必须小于 order_price_range_times_n * N
};
enum EnumEnterSignalType
{
    ENTER_SIGNAL_TYPE_IGNORE = 0,
    ENTER_SIGNAL_TYPE_BUY,
    ENTER_SIGNAL_TYPE_SELL
};
struct EnterSignal
{
    EnumEnterSignalType  type; // 
    double price;
};
class CSystem1Strategy
{
public:
    void Init();
    void ProcessTick(const Tick& tick);
    void Deinit();
private:
    // 尝试更新头寸单位, 如果头寸单位发生变化，则看是否需要更新订单
    void TryUpdatePositionUnit();
    bool IsCurrentPeriod(datetime t); 
 
    void EnterMarket();
    void ExitMarket();
    void RefreshPeriodData();
    // 算出入市信号
    int GetEnterSignal(EnterSignal& signal);
    // 根据入市信号下订单
    int PlaceOrder(const EnterSignal& signal);
    // 更新上次突破，看是亏损还是盈利
    void RefreshLastBreakThrough();
    void RollBreakThrough(EnumBreakThourghDirection direction, double price);
    void RefreshPositionUnit();
    // 进行头寸规模限制
    int LimitPosition();
private:
    Tick tick_;
    
    System1Config config_;
    
    CPositionManager* position_manager_;
    COrderManager* order_manager_;
    CBreakthroughManager* breakthrough_mgr_;
    
    // 每个时间段(bar)内的数据
    datetime period_time_;
    double max_price_of_10_;
    double min_price_of_10_;
    double max_price_of_20_;
    double min_price_of_20_;
    double max_price_of_55_;
    double min_price_of_55_;
    double N_;
    bool already_exit_buy_;
    bool already_exit_sell_;
    
    double U_;
    
    BreakThroughInfo last_break_through_;
    BreakThroughInfo break_through_;
    
    
    
};

void CSystem1Strategy::ProcessTick(const Tick& tick)
{
  // 1. 看是否到时间要更行N，更新N,同时计算所有仓位，看是否需要变化(部分卖出)
  // 2. 计算现有订单是否需要盈利卖出的
  // 3. 看今天是否有突破（入市信号)，如果有不能忽略的入市信号， 则进行如下操作
  //     3.1 如果今天没有交易，根据突破价尝试买入
  //     3.2 如果今天有交易, 尝试按照0.5N的方式加仓
  tick_ = tick;
  RefreshPeriodData();
  TryUpdatePositionUnit();
  // 获利退出
  ExitMarket();
  // 入市
  EnterMarket();
}
int CSystem1Strategy::PlaceOrder(const EnterSignal &signal)
{
    if (ENTER_SIGNAL_TYPE_IGNORE == signal.type) {
        return 1;
    }
    double price = ENTER_SIGNAL_TYPE_BUY == signal.type ? tick_.ask : tick_.bid;
    if (MathAbs(price - signal.price) > config_.order_price_range_times_n * N_ ) {
        // 当前市场价格和突破价格差距已经太大，超过范围则不下单
        Print("当前市场价格超过突破价格太多");
        // return 2;
    }
    double stoploss = ENTER_SIGNAL_TYPE_BUY == signal.type ? price - config_.stop_loss_times_n * N_ : price + config_.stop_loss_times_n*N_;
    int op;
    if (config_.use_limit_order) {
        op = ENTER_SIGNAL_TYPE_BUY == signal.type ? OP_BUYLIMIT : OP_SELLLIMIT;
    } else {       
        op = ENTER_SIGNAL_TYPE_BUY == signal.type ? OP_BUY : OP_SELL;
    }
    
    int ticket = order_manager_->.OpenOrderSmart(tick_.symbol, op, g_position_unit_system1, price, config_.slippage, stoploss);
    return ticket;
}

int CSystem1Strategy::LimitPosition(void)
{
    //进行仓位限制
    
         // 根据加仓条件进行加仓，最多到4U，中间的突破忽略掉

          // 加仓条件：当前价格超过突破价格(最后订单价格)的0.5N, 1N, 1.5N, 如果已经开仓，则持续加仓到最多4U
         int total_unit = 0;
         int strong_related_unit = 0;
         int weak_related_unit = 0;
         // 可以加仓， 计算总头寸单位
         if (total_unit >= 12 || strong_related_unit >= 6 || weak_related_unit>=10) {
            //不能加
            return;
         }
         if (orders_count >= 4) {
             return;
         } 
         double total_lots = 0;
         for (int i=0; i<ArraySize(orders); ++i) {
             total_lots += orders[i].lots;
         }
         bool isBuySignal = orders[0].type == OP_BUY;
         double price = isBuySignal ? g_cur_ask : g_cur_bid;
         
         double position_limit = g_position_unit_system1 * 4;
         
         
         // 要计算加仓的价格, [突破价,突破价+0.5N, 突破价+N, 突破价+1.5N】
         // 如果有滑点，以上一份订单的实际成交价格为基础，有上限吗?允许最大滑点多少?]
         double lots  = position_limit - total_lots > g_position_unit_system1 ? g_position_unit_system1 : position_limit - total_lots;
         int slippage = 3;
         double stoploss = isBuySignal ? price - 2*g_N : price + 2*g_N;
       
         

          if (isBuySignal && 
          (price < orders[orders_count-1].open_price + 0.5*g_N || price > orders[orders_count-1].open_price+g_N)) {
              // 不满足加仓条件
              return;
          }
          if (!isBuySignal &&
          ( price > orders[orders_count-1].open_price - 0.5*g_N || price < orders[orders_count-1].open_price-g_N)) {
              // 不满足加仓条件
              return;
          }
}
 // 入市策略1
  void CSystem1Strategy::EnterMarket()
  {
      COrder orders[];
      int orders_count = order_manager->SelectOrders(g_symbol,orders);
      if (orders_count < 0) {
          Print("error:SelectOrder return ", orders_count);
          return;
      }
      
      if (orders_count == 0) {
          // 空仓，准备入场
           //尝试开仓:条件，发生了突破，且突破不能忽略
           // 更新突破信息
           EnterSignal signal;
           int ret = GetEnterSignal(signal);
           if (signal.type == ENTER_SIGNAL_TYPE_IGNORE) {
               return;
           
           }
           LimitPosition();
           PlaceOrder(signal);
           
      } else {
          LimitPosition();


         
         int ticket = g_order_manager.OpenOrder(g_symbol, isBuySignal?OP_BUY:OP_SELL, lots, price, slippage, stoploss);
         Print("下单:lots=", lots, ",price=", price, ", stoploss=", stoploss, ",ticket=", ticket);
         if (ticket > 0) {
            Print("加仓了");
            // 设置止损价格，需要调整以前订单的止损价格: 将之前的头寸止损价格提高0.5N
            for (int i=0; i<orders_count;++i) {
            
                double new_stoploss = isBuySignal?orders[i].open_price+0.5*g_N:orders[i].open_price-0.5*g_N;
                new_stoploss = NormalizeDouble(new_stoploss, MarketInfo(g_symbol, MODE_DIGITS));
                if (OrderModify(orders[i].ticket, orders[i].open_price, new_stoploss, 0, 0)) {
                    Print("update stoploss succeed:ticket=", orders[i].ticket, ", stoploss=", new_stoploss, ",N=",g_N);
                } else {
                    Print("update stoploss fail:ticket=", orders[i].ticket, ", stoploss=", new_stoploss, ",N=",g_N, ",error=", GetLastError());
                }
               
            }  
         }
         if (ticket < 0) {
             Print("Open order error:", GetLastError());
            
         }
          
      }

      
  
      
  }
void CSystem1Strategy::ExitMarket(void)
{
     if (!already_exit_buy_ && tick_.bid < min_price_of_10_) {
         already_exit_buy_ = true;         
         Print("Exit: 跌破10日低点,bid= ", g_cur_bid, ",price_min_10d=", g_min_price_in_10d);
         order_manager_->CloseOrders(config_.symbol, true, tick_.bid, config_.slippage);
     }
     
     if (!already_exit_sell_ && tick_.ask > max_price_of_10_) {
         already_exit_sell_  = true;
         Print("Exit: 突破10日高点,ask= ", g_cur_ask, ",price_max_10d=", g_max_price_in_10d);
          order_manager_->CloseOrders(config_.symbol, false, tick_.ask, config_.slippage);
 
     }
}
void CSystem1Strategy::RefreshLastBreakThrough()
{
    if (!last_break_through_.IsValid()) {
        return;
    }
    if (last_break_through_.trade_status != TRADE_STATUS_HOLD) {
        return;
    }


   if (BREAK_THROUGH_UP == last_break_through_.direction) {
        // 假设是个买单
        if (tick_.bid < last_break_through_.price - config_.stop_loss_times_n * N_) {
            last_break_through_.trade_status = TRADE_STATUS_LOSS;// 亏损
        } else if (tick_.bid < min_price_of_10_) {
            if (tick_.bid > last_break_through_.price) {
                last_break_through_.trade_status = TRADE_STATUS_PROFIT;// 盈利
            } else {
                last_break_through_.trade_status = TRADE_STATUS_LOSS;// 亏损
            }
        }
   } else {
        // 假设是个卖单
        if (tick_.ask > last_break_through_.price + config_.stop_loss_times_n * N_) {
            last_break_through_.trade_status = TRADE_STATUS_LOSS;// 亏损
        } else if (tick_.ask > max_price_of_10_) {
            if (tick_.ask < last_break_through_.price) {
                last_break_through_.trade_status = TRADE_STATUS_PROFIT;// 盈利
            } else {
                last_break_through_.trade_status = TRADE_STATUS_LOSS;// 盈利
            }
        }
   }
        
    
}

void CSystem1Strategy::RollBreakThrough(EnumBreakThourghDirection direction, double price)
{
    if (break_through_.IsValid()
         && IsCurrentPeriod(break_through_.t) 
         && break_through_.direction == direction) {
        // 同一个时间周期，相同方向的突破忽略
        return;

    }
    if (break_through_.IsValid()) {
        last_break_through_ = break_through_;
        
    }
    break_through_.Init(tick_.timestamp, direction, price);
}
int CSystem1Strategy::GetEnterSignal(EnterSignal &signal)
{
    
    // 更新上次突破，看是盈利还是亏损
    RefreshLastBreakThrough();

    // 重新计算突破
    // 55日突破不用看上次突破
    if (tick_.ask > max_price_of_55_) {
    // 55日突破
        signal.price = max_price_of_55_;
        signal.type = ENTER_SIGNAL_TYPE_BUY;
        RollBreakThrough(BREAK_THROUGH_UP, max_price_of_20_);
        return 0;
    }
    if (tick_.bid < min_price_of_55_) {
        signal.price = min_price_of_55_;
        signal.type = ENTER_SIGNAL_TYPE_SELL;
        RollBreakThrough(BREAK_THROUGH_DOWN, min_price_of_20_);
        return 0;
    }
    if (tick_.ask > max_price_of_20_) {
        RollBreakThrough(BREAK_THROUGH_UP, max_price_of_20_);
        if (last_break_through_.IsLoss()) {
            signal.price = max_price_of_20_;
            signal.type = ENTER_SIGNAL_TYPE_BUY;           
            return 0;
        }
    }
    if (tick_.bid < min_price_of_20_) {
        RollBreakThrough(BREAK_THROUGH_UP, max_price_of_20_);
        if (last_break_through_.IsLoss()) {
            signal.price = min_price_of_20_;
            signal.type = ENTER_SIGNAL_TYPE_SELL;
            return 0;
        }
    }
    signal.type = ENTER_SIGNAL_TYPE_IGNORE;
    signal.price = 0;
    return 0;

}

bool CSystem1Strategy::IsCurrentPeriod(datetime t) 
{
    return iBarShift(config_.symbol, config_.timeframe, t, false) > 0;
}
void CSystem1Strategy::RefreshPeriodData()
 {
 
   if (!IsCurrentPeriod(period_time_)) {
       // 更新period中的数据
       period_time_ = tick_.timestamp;       
       max_price_of_10_ = iHigh(config_.symbol, config_.timeframe, iHighest(config_.symbol, config_.timeframe, MODE_HIGH, 10, 1));
       min_price_of_10_ = iLow(config_.symbol, config_.timeframe, iLowest(config_.symbol, config_.timeframe, MODE_LOW, 10, 1));
       max_price_of_20_ = iHigh(config_.symbol, config_.timeframe, iHighest(g_symbol, config_.timeframe, MODE_HIGH, 20, 1));
       min_price_of_20_ = iLow(config_.symbol, config_.timeframe, iLowest(g_symbol, config_.timeframe, MODE_LOW, 20, 1));
       max_price_of_55_ = iHigh(config_.symbol, config_.timeframe, iHighest(g_symbol, config_.timeframe, MODE_HIGH, 55, 1));
       min_price_of_55_ = iLow(config_.symbol, config_.timeframe, iLowest(g_symbol, config_.timeframe, MODE_LOW, 55, 1));  
       N_ = iN(config_.symbol, config_.timeframe, 20, 1);
       already_exit_buy_ = false;
       already_exit_sell_ = false;  
   }  
 }
 
 
/** 计算每点代表的美元数 */
double GetDollarsPerPoint(string symbol)
{
   double currency = MarketInfo(symbol, MODE_LOTSIZE) * MarketInfo(symbol, MODE_POINT);
   string account_currency = AccountCurrency();
   string quote_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   if (account_currency == quote_currency) {
       return currency;
   } else {
      // 查找汇率 quote->account
      if (quote_currency == "JPY") {
          return currency / MarketInfo("USDJPYpro", MODE_ASK);
          
      }
      if (quote_currency == "AUD") {
          return currency * MarketInfo("AUDUSDpro", MODE_BID);
      }
      if (quote_currency == "CAD") {
          return currency / MarketInfo("USDCADpro", MODE_ASK);
      }
   }
   return 0;

}

 

// 计算头寸规模单位，算法：头寸规模单位=账户的1%/市场的绝对波动幅度=账户的1%/(N * 每一点代表的美元数)
// 返回值：合约数，比如外汇的最小合约数是0.01，
void  CSystem1Strategy::RefreshPositionUnit() 
{
   double N_ = iATR(config_.symbol, config_.timeframe, 20, 1);
   double N = N_ /MarketInfo(config_.symbol, MODE_POINT);  
   double fund_per_point =  GetDollarsPerPoint(config_.symbol);
   U_ = config_.fund * 0.01 / (N * fund_per_point);
   double minlot = MarketInfo(config_.symbol, MODE_MINLOT);
   double lotstep = MarketInfo(config_.symbol, MODE_LOTSTEP);
   if (U_ < minlot) {
      // 1个最小的lot都不能买，这个symbol不能交易
       U_ = 0;
   } else {
       int times =  (U_ - minlot ) / lotstep;
       U_ = minlot + times * lotstep;
   }
   
   
}
