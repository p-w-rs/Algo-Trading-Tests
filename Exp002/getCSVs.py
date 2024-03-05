import sys
import datatable as dt
from tqdm import tqdm

from alpaca.data import StockBarsRequest, StockHistoricalDataClient, TimeFrame
from datetime import datetime
from dateutil.relativedelta import relativedelta

API_KEY = "PKHJY0DEIRHW1SKBO3H6"
SECRET_KEY = "PvDihqrgz6TAoB49O9sAVBhHalgcPnBIT7vdvWfC"
daytovec = {
    0: "1,0,0,0,0,0",
    1: "0,1,0,0,0,0",
    2: "0,0,1,0,0,0",
    3: "0,0,0,1,0,0",
    4: "0,0,0,0,1,0",
    5: "0,0,0,0,0,1",
}

symbolList = []
if sys.argv[1] == "sp500":
    symbolList = dt.fread("sp500.csv").to_list()[0]
elif sys.argv[1] == "etfs":
    symbolList = dt.fread("etfs.csv").to_list()[0]
else:
    exit()

stock_client = StockHistoricalDataClient(API_KEY, SECRET_KEY)

end = datetime.today()
start = end + relativedelta(years=-5)

for symbol in tqdm(symbolList):
    request_params = StockBarsRequest(
        symbol_or_symbols=[symbol],
        timeframe=TimeFrame.Hour,
        start=start,
        end=end,
        limit=None,
        adjustment=None,
        feed=None,
    )
    stock_bars = stock_client.get_stock_bars(request_params)
    csv_str = "close,high,low,open,m,t,w,th,f,s,trade_count,volume,vwap\n"
    lst = stock_bars[symbol]
    for entry in lst:
        csv_str += str(entry.close) + ","
        csv_str += str(entry.high) + ","
        csv_str += str(entry.low) + ","
        csv_str += str(entry.open) + ","
        csv_str += daytovec[entry.timestamp.weekday()] + ","
        csv_str += str(entry.trade_count) + ","
        csv_str += str(entry.volume) + ","
        csv_str += str(entry.vwap) + "\n"
    f = open("csvDATA/" + symbol + ".csv", "w")
    f.write(csv_str)
    f.close()
