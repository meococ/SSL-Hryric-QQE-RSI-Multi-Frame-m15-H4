//+------------------------------------------------------------------+
//|                                                      QQE MOD.mq5 |
//|                                        Copyright © 2022, Centaur |
//|                            https://www.mql5.com/en/users/centaur |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2022, Centaur"
#property link      "https://www.mql5.com/en/users/centaur"
#property version   "1.00"
#property description   "Tradingview Indicator by Mihkel00."
#property description   "     "
#property description   "https://www.tradingview.com/script/TpUW4muw-QQE-MOD/"
#property indicator_separate_window
#property indicator_level1  0
#property indicator_buffers 23
#property indicator_plots   2
//--- plot Trailing Line
#property indicator_label1  "Trailing Line"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrWhite
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- plot Smoothed RSI
#property indicator_label2  "Smoothed RSI"
#property indicator_type2   DRAW_COLOR_HISTOGRAM
#property indicator_color2  clrDarkTurquoise,clrMediumVioletRed,clrDarkSlateGray
#property indicator_style2  STYLE_SOLID
#property indicator_width2  5
//--- input parameters
input group                   "First QQE Settings:"
input int                     inp_qqe1_length         = 6;              // RSI Length
input int                     inp_qqe1_smooth         = 5;              // RSI Smoothing Length
input int                     inp_qqe1_factor         = 3;              // QQE Factor
input ENUM_APPLIED_PRICE      inp_qqe1_price          = PRICE_CLOSE;    // Price Source
input group                   "Bollinger Bands Settings:"
input int                     inp_bb_length           = 50;             // BB Length
input double                  inp_bb_multiplier       = 0.35;           // BB Multiplier
input group                   "Second QQE Settings:"
input int                     inp_qqe2_length         = 6;              // RSI Length
input int                     inp_qqe2_smooth         = 5;              // RSI Smoothing Length
input double                  inp_qqe2_factor         = 1.61;           // QQE Factor
input int                     inp_qqe2_threshold      = 3;              // QQE Threshold
input ENUM_APPLIED_PRICE      inp_qqe2_price          = PRICE_CLOSE;    // Price Source
//--- indicator plot buffers
double                        Trailing_Line[];
double                        Smoothed_RSI[];
double                        Smoothed_RSI_Color[];
//--- indicator calculation buffers
double                        Rsi1[];
double                        Rsi2[];
double                        RsiMa1[];
double                        RsiMa2[];
double                        AtrRsi1[];
double                        AtrRsi2[];
double                        MaAtrRsi1[];
double                        MaAtrRsi2[];
double                        MaMaAtrRsi1[];
double                        MaMaAtrRsi2[];
double                        dar1[];
double                        dar2[];
double                        TrLevelSlow1[];
double                        TrLevelSlow2[];
double                        bb_input[];
double                        basis[];
double                        dev1[];
double                        dev2[];
double                        upper[];
double                        lower[];
//--- indicator variables
int                           qqe1_length;
int                           qqe1_smooth;
int                           qqe1_factor;
int                           bb_length;
double                        bb_multiplier;
int                           qqe2_length;
int                           qqe2_smooth;
double                        qqe2_factor;
int                           qqe2_threshold;
int                           rsi1_handle;
int                           rsi2_handle;
int                           wilder1;
int                           wilder2;
double                        trr1;
double                        trr2;
double                        dv1;
double                        dv2;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- verify input parameters
   qqe1_length = inp_qqe1_length < 1 ? 1 : inp_qqe1_length;
   qqe1_smooth = inp_qqe1_smooth < 1 ? 1 : inp_qqe1_smooth;
   qqe1_factor = inp_qqe1_factor < 1 ? 1 : inp_qqe1_factor;
   bb_length = inp_bb_length < 1 ? 1 : inp_bb_length;
   bb_multiplier = inp_bb_multiplier < 0.1 ? 0.1 : inp_bb_multiplier;
   qqe2_length = inp_qqe2_length < 1 ? 1 : inp_qqe2_length;
   qqe2_smooth = inp_qqe2_smooth < 1 ? 1 : inp_qqe2_smooth;
   qqe2_factor = inp_qqe2_factor < 0.1 ? 0.1 : inp_qqe2_factor;
   qqe2_threshold = inp_qqe2_threshold < 1 ? 1 : inp_qqe2_threshold;
   wilder1 = qqe1_length * 2 - 1;
   wilder2 = qqe2_length * 2 - 1;
//--- indicator buffers mapping
   SetIndexBuffer(0, Trailing_Line, INDICATOR_DATA);
   SetIndexBuffer(1, Smoothed_RSI, INDICATOR_DATA);
   SetIndexBuffer(2, Smoothed_RSI_Color, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3, Rsi1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, Rsi2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, RsiMa1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, RsiMa2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, AtrRsi1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, AtrRsi2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, MaAtrRsi1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, MaAtrRsi2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, MaMaAtrRsi1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, MaMaAtrRsi2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, dar1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, dar2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(15, TrLevelSlow1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(16, TrLevelSlow2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(17, bb_input, INDICATOR_CALCULATIONS);
   SetIndexBuffer(18, basis, INDICATOR_CALCULATIONS);
   SetIndexBuffer(19, dev1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(20, dev2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(21, upper, INDICATOR_CALCULATIONS);
   SetIndexBuffer(22, lower, INDICATOR_CALCULATIONS);
//--- set indicator accuracy
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
//--- set indicator name display
   string price1 = inp_qqe1_price == PRICE_OPEN ? "Open" : inp_qqe1_price == PRICE_HIGH ? "High" : inp_qqe1_price == PRICE_LOW ? "Low" : inp_qqe1_price == PRICE_CLOSE ? "Close" : inp_qqe1_price == PRICE_MEDIAN ? "Median" : inp_qqe1_price == PRICE_TYPICAL ? "Typical" : inp_qqe1_price == PRICE_WEIGHTED ? "Weighted" : " ";
   string price2 = inp_qqe1_price == PRICE_OPEN ? "Open" : inp_qqe1_price == PRICE_HIGH ? "High" : inp_qqe2_price == PRICE_LOW ? "Low" : inp_qqe2_price == PRICE_CLOSE ? "Close" : inp_qqe2_price == PRICE_MEDIAN ? "Median" : inp_qqe2_price == PRICE_TYPICAL ? "Typical" : inp_qqe2_price == PRICE_WEIGHTED ? "Weighted" : " ";
   string short_name = "QQE MOD (" + IntegerToString(qqe1_length) + ", " + IntegerToString(qqe1_smooth) + ", " + IntegerToString(qqe1_factor) + ", " + price1 + ", " + IntegerToString(bb_length) + ", " + DoubleToString(bb_multiplier, 2) + ", " + IntegerToString(qqe2_length) + ", " + IntegerToString(qqe2_smooth) + ", " + DoubleToString(qqe2_factor, 2) + ", " + IntegerToString(qqe2_threshold) + ", " + price2 + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
//--- sets drawing lines to empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
//--- initialize buffer elements
   ArrayInitialize(Trailing_Line, EMPTY_VALUE);
   ArrayInitialize(Smoothed_RSI, EMPTY_VALUE);
   ArrayInitialize(Smoothed_RSI_Color, EMPTY_VALUE);
   ArrayInitialize(Rsi1, 0.0);
   ArrayInitialize(Rsi2, 0.0);
   ArrayInitialize(RsiMa1, 0.0);
   ArrayInitialize(RsiMa2, 0.0);
   ArrayInitialize(AtrRsi1, 0.0);
   ArrayInitialize(AtrRsi2, 0.0);
   ArrayInitialize(MaAtrRsi1, 0.0);
   ArrayInitialize(MaAtrRsi2, 0.0);
   ArrayInitialize(MaMaAtrRsi1, 0.0);
   ArrayInitialize(MaMaAtrRsi2, 0.0);
   ArrayInitialize(dar1, 0.0);
   ArrayInitialize(dar2, 0.0);
   ArrayInitialize(TrLevelSlow1, 0.0);
   ArrayInitialize(TrLevelSlow2, 0.0);
   ArrayInitialize(bb_input, 0.0);
   ArrayInitialize(basis, 0.0);
   ArrayInitialize(dev1, 0.0);
   ArrayInitialize(dev2, 0.0);
   ArrayInitialize(upper, 0.0);
   ArrayInitialize(lower, 0.0);
//--- create RSI handles
   rsi1_handle = iRSI(_Symbol, _Period, qqe1_length, inp_qqe1_price);
   rsi2_handle = iRSI(_Symbol, _Period, qqe2_length, inp_qqe2_price);
//--- initialization succeeded
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- check period
   if(fmax(wilder1, fmax(wilder2, bb_length)) <= 1 || fmax(wilder1, fmax(wilder2, bb_length)) > rates_total)
      return(0);
//--- latest RSI data copy
   int copy;
   if(prev_calculated > rates_total || prev_calculated <= 0)
      copy = rates_total;
   else
     {
      copy = rates_total - prev_calculated;
      //--- last value is always copied
      copy++;
     }
//--- populate RSI buffers
   if(CopyBuffer(rsi1_handle, 0, 0, copy, Rsi1) <= 0)
      return(0);
   if(CopyBuffer(rsi2_handle, 0, 0, copy, Rsi2) <= 0)
      return(0);
//--- calculate start position
   int bar;
   if(prev_calculated == 0)
      bar = 0;
   else
      bar = prev_calculated - 1;
//--- main loop
   for(int i = bar; i < rates_total && !_StopFlag; i++)
     {
      if(i > fmax(wilder1, fmax(wilder2, bb_length)))
        {
         //--- first QQE calculation
         RsiMa1[i] = fEMA(i, qqe1_smooth, RsiMa1[i - 1], Rsi1);
         AtrRsi1[i] = fabs(RsiMa1[i - 1] - RsiMa1[i]);
         MaAtrRsi1[i] = fEMA(i, wilder1, MaAtrRsi1[i - 1], AtrRsi1);
         MaMaAtrRsi1[i] = fEMA(i, wilder1, MaMaAtrRsi1[i - 1], MaAtrRsi1);
         dar1[i] = MaMaAtrRsi1[i] * qqe1_factor;
         trr1 = TrLevelSlow1[i - 1];
         dv1 = trr1;
         if(RsiMa1[i] < trr1)
           {
            trr1 = RsiMa1[i] + dar1[i];
            if(RsiMa1[i - 1] < dv1)
              {
               if(trr1 > dv1)
                  trr1 = dv1;
              }
           }
         else
            if(RsiMa1[i] > trr1)
              {
               trr1 = RsiMa1[i] - dar1[i];
               if(RsiMa1[i - 1] > dv1)
                 {
                  if(trr1 < dv1)
                     trr1 = dv1;
                 }
              }
         TrLevelSlow1[i] = trr1;
         //--- BB calculation
         bb_input[i] = trr1 - 50.0;
         basis[i] = fSMA(i, bb_length, bb_input);
         dev1[i] = fSD(i, bb_length, bb_input);
         dev2[i] = dev1[i] * bb_multiplier;
         upper[i] = basis[i] + dev2[i];
         lower[i] = basis[i] - dev2[i];
         //--- second QQE calculation
         RsiMa2[i] = fEMA(i, qqe2_smooth, RsiMa2[i - 1], Rsi2);
         AtrRsi2[i] = fabs(RsiMa2[i - 1] - RsiMa2[i]);
         MaAtrRsi2[i] = fEMA(i, wilder2, MaAtrRsi2[i - 1], AtrRsi2);
         MaMaAtrRsi2[i] = fEMA(i, wilder2, MaMaAtrRsi2[i - 1], MaAtrRsi2);
         dar2[i] = MaMaAtrRsi2[i] * qqe2_factor;
         trr2 = TrLevelSlow2[i - 1];
         dv2 = trr2;
         if(RsiMa2[i] < trr2)
           {
            trr2 = RsiMa2[i] + dar2[i];
            if(RsiMa2[i - 1] < dv2)
              {
               if(trr2 > dv2)
                  trr2 = dv2;
              }
           }
         else
            if(RsiMa2[i] > trr2)
              {
               trr2 = RsiMa2[i] - dar2[i];
               if(RsiMa2[i - 1] > dv2)
                 {
                  if(trr2 < dv2)
                     trr2 = dv2;
                 }
              }
         TrLevelSlow2[i] = trr2;
        }
      //--- plot indicator
      Trailing_Line[i] = trr2 - 50.0;
      Smoothed_RSI[i] = RsiMa2[i] - 50.0;
      Smoothed_RSI_Color[i] = (RsiMa2[i] - 50.0) > qqe2_threshold && (RsiMa1[i] - 50.0) > upper[i] ? 0.0 : (RsiMa2[i] - 50.0) < -qqe2_threshold && (RsiMa1[i] - 50.0) < lower[i] ? 1.0 : 2.0;
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Function: Exponential Moving Average (EMA)                       |
//+------------------------------------------------------------------+
double fEMA(const int _position, const int _period, const double _prev_value, const double &_input[])
  {
   double result = 0.0;
   double alpha = 2.0 / (_period + 1.0);
   result = _input[_position] * alpha + _prev_value * (1 - alpha);
   return(result);
  }
//+------------------------------------------------------------------+
//| Function: Simple Moving Average (SMA)                            |
//+------------------------------------------------------------------+
double fSMA(const int _position, const int _period, const double &_input[])
  {
   double result = 0.0;
   double sum = 0.0;
   for(int k = 0; k < _period; k++)
      sum += _input[_position - k];
   result = sum / _period;
   return(result);
  }
//+------------------------------------------------------------------+
//| Function: Standard Deviation (SD)                                |
//+------------------------------------------------------------------+
double fSD(const int _position, const int _period, const double &_input[])
  {
   double result = 0.0, sum = 0.0, mean = 0.0;
   for(int k = 0; k < _period; k++)
      sum += _input[_position - k];
   mean = sum / _period;
   double dev = 0.0;
   for(int k = 0; k < _period; k++)
      dev += pow(_input[_position - k] - mean, 2);
   result = sqrt(dev / _period);
   return (result);
  }
//+------------------------------------------------------------------+
