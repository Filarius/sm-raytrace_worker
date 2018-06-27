#pragma semicolon 1

#define DEBUG

#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>
#include <socket>

#pragma newdecls required

ConVar g_hDBName = null;
Database g_hDatabase = null;
//const int iPackSize = 50;
 // = iPackSize * 3

char cBuffer[10240000];
int iBufSize = 0;



public Plugin myinfo = 
{
	name = "Raytracer worker",
	author = "Filarius",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://github.com/Filarius/sm-raytrace_worker"
};

ConVar SocketPort;
int iSocketPort;

public void OnPluginStart()
{
	g_hDBName = CreateConVar("sm_filarius_dbname", "default", "name of the database to use");
	SocketPort = CreateConVar("sm_socket_port", "40000", "name of the database to use");
	
	//RegServerCmd("trace", Cmd_callback);
	SocketSetOption(INVALID_HANDLE, DebugMode, 1);
    /*
	Handle socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetOption(socket, SocketSendLowWatermark, 24);
	SocketSetOption(socket, SocketReceiveLowWatermark, 24);
	SocketSetOption(socket, CallbacksPerFrame, 100000);
	SocketSetOption(socket, ForceFrameLock, false);
	SocketBind(socket, "0.0.0.0", 40000);
	SocketListen(socket, OnSocketIncoming);
*/

	PrintToServer("Plugin loaded.");
}


public void OnConfigsExecuted()
{
	char cDBName[64];
	g_hDBName.GetString(cDBName, 64);
	//Database.Connect(SQL_ConnectToDatabase, cDBName);

	int iSocketPort = GetConVarInt(SocketPort);

	Handle socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetOption(socket, SocketSendLowWatermark, 24);
	SocketSetOption(socket, SocketReceiveLowWatermark, 24);
	SocketSetOption(socket, CallbacksPerFrame, 100000);
	SocketSetOption(socket, ForceFrameLock, false);
	SocketBind(socket, "0.0.0.0", iSocketPort);
	SocketListen(socket, OnSocketIncoming);
}


public void OnSocketIncoming(Handle socket, Handle newSocket, char[] remoteIP, int remotePort, int arg) 
{
	PrintToServer("%s:%d connected", remoteIP, remotePort);

	// setup callbacks required to 'enable' newSocket
	// newSocket won't process data until these callbacks are set
	SocketSetReceiveCallback(newSocket, OnChildSocketReceive);
	SocketSetDisconnectCallback(newSocket, OnChildSocketDisconnected);
	SocketSetErrorCallback(newSocket, OnChildSocketError);

	//SocketSend(newSocket, "send quit to quit\n");
}


public void OnSocketError(Handle socket, int errorType, int errorNum, int arg)
{ 

	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}


void RayDecode(char[] buffer,int startPos, float[3] pos, float[3] angle,float[3] hit)
{

}

public void OnChildSocketReceive(Handle socket, char[] receiveData, int dataSize, int hFile)
{
	// send (echo) the received data back
	// SocketSend(socket, receiveData);
	// close the connection/socket/handle if it matches quit
	char tmp[10];
	/*
	LogMessage("SocketData");
	LogMessage("Bytes per Packet");
	IntToString(iPackSize*4*6,tmp,10);
    LogMessage(tmp);
    LogMessage("Message size");
	IntToString(dataSize,tmp,10);
    LogMessage(tmp);
    LogMessage("Message");
    LogMessage(receiveData);
    */

    /*
    LogMessage("BuffSize");
	IntToString(iBufSize,tmp,10);
	LogMessage(tmp);
	LogMessage("datasize");
	IntToString(dataSize,tmp,10);
	LogMessage(tmp);
	*/
	for(int i=0;i<dataSize;i++)
	{
	    cBuffer[iBufSize+i] = receiveData[i];
	}
	iBufSize += dataSize;

	if( iBufSize >= 24 ) // have all bulk data received
	{
	    int iPackSize = iBufSize / 24 ;
	    //int iPackCount = iBufSize / (4*6);
	    float[] flHits = new float[iPackSize*6];// = new float[iPackSize*6];
	    int iHitsCount;
        //LogMessage("Decoding");

	    for(int i=0;i<iPackSize;i++) // iterate rays
	    {
	        /*
	        LogMessage("i");
	        IntToString(i,tmp,10);
            LogMessage(tmp);
            */
	        int shift = i*24;
            float flRay[6];
	        for(int j=0;j<6;j++) // iterate floats
	        {
	            /*
	            LogMessage("j");
	            IntToString(j,tmp,10);
                LogMessage(tmp);
                */
	            int jShift = j*4;
	            int iVal = 0;
	            /*
	            LogMessage("arrayIndex");
	            IntToString(shift + (jShift + 0),tmp,10);
                LogMessage(tmp);
                LogMessage("iVals");
                */
	            iVal = cBuffer[shift + (jShift + 0)];
	            /*
	            IntToString(iVal,tmp,10);
                LogMessage(tmp);
                */
	            iVal = iVal << 8;
	            /*
	            IntToString(iVal,tmp,10);
                LogMessage(tmp);
                */
	            iVal = cBuffer[shift + (jShift + 1)] + iVal;
	            /*
	            IntToString(iVal,tmp,10);
                LogMessage(tmp);
                */
	            iVal = iVal << 8;
	            /*
	            IntToString(iVal,tmp,10);
                LogMessage(tmp);
                */
	            iVal = cBuffer[shift + (jShift + 2)] + iVal;
	            /*
	            IntToString(iVal,tmp,10);
                LogMessage(tmp);
                */
	            iVal = iVal << 8;
	            /*
	            IntToString(iVal,tmp,10);
                LogMessage(tmp);
                */
	            iVal = cBuffer[shift + (jShift + 3)] + iVal;
	            /*
	            IntToString(iVal,tmp,10);
                LogMessage(tmp);
                */
	            flRay[j] = view_as<float>(iVal);
	            /*
	            LogMessage("got float");
	            FloatToString(flRay[j],tmp,10);
                LogMessage(tmp);
                */
	        }
	        float flPoint[3];
	        float flAngle[3];
	        float flHit[3];

	        flPoint[0] = flRay[0];
	        flPoint[1] = flRay[1];
	        flPoint[2] = flRay[2];
	        flAngle[0] = flRay[3];
	        flAngle[1] = flRay[4];
	        flAngle[2] = flRay[5];

	        Trace(flPoint,flAngle,flHit);

	        int iHitsPos = iHitsCount*6;

	        flHits[iHitsPos+0] = flPoint[0];
	        flHits[iHitsPos+1] = flPoint[1];
	        flHits[iHitsPos+2] = flPoint[2];
	        flHits[iHitsPos+3] = flHit[0];
	        flHits[iHitsPos+4] = flHit[1];
	        flHits[iHitsPos+5] = flHit[2];

	        iHitsCount += 1;
	    }

	    // encode raytracing results

	    char[] cSendBuff= new char[iPackSize*24];
	    int iSendBuffPos = 0;
	    /*
	    LogMessage("ENCODING");
	    LogMessage("SendBuff size");
	    IntToString(iPackSize*6*4,tmp,10);
        LogMessage(tmp);
        */
	    for(int i=0;i<iPackSize;i++) //iterate ray result
	    {
	        /*
            LogMessage("i");
            IntToString(i,tmp,10);
            LogMessage(tmp);
            */
	        int shift = i*6;
	        for(int j=0;j<6;j++) //iterate floats
	        {
	            /*
	            LogMessage("j");
                IntToString(j,tmp,10);
                LogMessage(tmp);
                LogMessage("iSendBuffPos");
                IntToString(iSendBuffPos,tmp,10);
                LogMessage(tmp);
                LogMessage("Shift + j");
                IntToString(shift + j,tmp,10);
                LogMessage(tmp);
                LogMessage("Float");
                FloatToString(flHits[shift + j],tmp,10);
                LogMessage(tmp);
                */

	            int iTmp = view_as<int>(flHits[shift + j]);
	            /*
	            LogMessage("iTmp");
	            IntToString(iTmp,tmp,10);
                LogMessage(tmp);
                LogMessage(cSendBuff[iSendBuffPos+1]);
                */
	            cSendBuff[iSendBuffPos+0] = view_as<char>(iTmp  & 255);
	            iTmp = iTmp  >> 8;
	            /*
	            IntToString(iTmp,tmp,10);
                LogMessage(tmp);
                LogMessage(cSendBuff[iSendBuffPos+0]);
                */
	            cSendBuff[iSendBuffPos+1] = view_as<char>(iTmp  & 255);
	            iTmp = iTmp  >> 8;
	            /*
	            IntToString(iTmp,tmp,10);
                LogMessage(tmp);
                LogMessage(cSendBuff[iSendBuffPos+1]);
                */
	            cSendBuff[iSendBuffPos+2] = view_as<char>(iTmp  & 255);
	            iTmp = iTmp  >> 8;
	            /*
	            IntToString(iTmp,tmp,10);
                LogMessage(tmp);
                LogMessage(cSendBuff[iSendBuffPos+1]);
                */
	            cSendBuff[iSendBuffPos+3] = view_as<char>(iTmp  & 255);
	            iSendBuffPos += 4;

	        }
	    }
	    //send encoded floats
	    SocketSend(socket,cSendBuff, iPackSize*24);

	    //remove from buffer already sended data

	    int bounds = iPackSize*24;
	    for(int i = bounds; i<iBufSize; i++)
	    {
	       // IntToString(i,tmp,10);
	        cBuffer[i-bounds] = cBuffer[i];
	    }
        iBufSize -= bounds;
        /*
        IntToString(iBufSize,tmp,10);
        LogMessage(tmp);

	    LogMessage("Bounds");
	    IntToString(bounds,tmp,10);
        LogMessage(tmp);
        IntToString(iBufSize,tmp,10);
        LogMessage(tmp);
        */


	}

}

public void OnChildSocketDisconnected(Handle socket, int hFile) 
{
	// remote side disconnected

	CloseHandle(socket);
}

public void OnChildSocketError(Handle socket, int errorType, int errorNum, any ary) 
{
	// a socket error occured

	LogError("child socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}













public void OnMapStart()
{
	CreateTimer(1.0, Timer_ProcessDB, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
}

public Action Cmd_callback(int iArgs)
{
//Code here
return Plugin_Handled;
}

public Action Timer_ProcessDB(Handle hTimer)
{
	if (!g_hDatabase)
		return Plugin_Continue;
	ProcessDB(g_hDatabase);
	return Plugin_Continue;
}

public void SQL_ConnectToDatabase(Database hDB, const char[] cError, any rpvData)
{
	if (hDB)
		g_hDatabase = hDB;
	else
		SetFailState("Unable to connect to database!"); //Выгружаем плагин с ошибкой
}

bool Trace(float flPos[3], float flAngles[3], float flEnd[3])
{
    //LogMessage("Trace !");
	Handle hTrace = TR_TraceRayEx(flPos, flAngles, MASK_VISIBLE, RayType_Infinite); //Нам же нужно сделать модель, она по логике должна содержать ток видимые части

	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(flEnd, hTrace);

        char tmp[255];

        /*
        LogMessage("tracing");
        Format(tmp, 255, "%.2f %.2f %.2f",flPos[0],flPos[1],flPos[2] );
        LogMessage(tmp);
        Format(tmp, 255, "%.2f %.2f %.2f",flAngles[0],flAngles[1],flAngles[2] );
        LogMessage(tmp);
        Format(tmp, 255, "%.2f %.2f %.2f",flEnd[0],flEnd[1],flEnd[2] );
        LogMessage(tmp);
        */
		delete hTrace;
		return true;
	}
	else
	{
	    float flHitPosition[3];
	    flHitPosition[0]=1;
	    flHitPosition[1]=1;
	    flHitPosition[2]=1;
	    if(FloatAbs(flAngles[0]-0)<1)
                {
                    if(FloatAbs(flAngles[1]-0)<1)
                    {
                        flHitPosition[0] = flPos[0]+100 ;
                        flHitPosition[1] = flPos[1]+10 ;
                        flHitPosition[2] = flPos[2]+10 ;
                    } else
                    if(FloatAbs(flAngles[1]-180)<1)
                    {
                        flHitPosition[0] = flPos[0]-100 ;
                        flHitPosition[1] = flPos[1]+10 ;
                        flHitPosition[2] = flPos[2]+10 ;
                    } else
                    if(FloatAbs(flAngles[1]-90)<1)
                    {
                        flHitPosition[0] = flPos[0]+10 ;
                        flHitPosition[1] = flPos[1]+100 ;
                        flHitPosition[2] = flPos[2]+10 ;
                    } else
                    if(FloatAbs(flAngles[1]+90)<1)
                    {
                        flHitPosition[0] = flPos[0]+10 ;
                        flHitPosition[1] = flPos[1]-100 ;
                        flHitPosition[2] = flPos[2]+10 ;
                    }
                } else
                if(FloatAbs(flAngles[0]+90)<1)
                {
                        flHitPosition[0] = flPos[0]+10 ;
                        flHitPosition[1] = flPos[1]+10 ;
                        flHitPosition[2] = flPos[2]+100 ;
                } else
                if(FloatAbs(flAngles[0]-90)<1)
                {
                        flHitPosition[0] = flPos[0]+10 ;
                        flHitPosition[1] = flPos[1]+10 ;
                        flHitPosition[2] = flPos[2]-100 ;
                }
        flEnd[0] = flHitPosition[0];
        flEnd[1] = flHitPosition[1];
        flEnd[2] = flHitPosition[2];
        /*
	    char tmp[255];
        LogMessage("tracing");
        Format(tmp, 255, "%.2f %.2f %.2f",flPos[0],flPos[1],flPos[2] );
        LogMessage(tmp);
        Format(tmp, 255, "%.2f %.2f %.2f",flAngles[0],flAngles[1],flAngles[2] );
        LogMessage(tmp);
        Format(tmp, 255, "%.2f %.2f %.2f",flEnd[0],flEnd[1],flEnd[2] );
        LogMessage(tmp);
        */
	    delete hTrace;
	    return false;
	}



}

void PrintSQLError(Database hDB)
{
	char cError[255];
	SQL_GetError(hDB, cError, sizeof(cError));
	LogError("Failed to query (error: %s)", cError);
}

void ProcessDB(Database hDB)
{
    char tmp[10];

	DBResultSet hQuery = null;

	if (!(hQuery = SQL_Query(hDB, "SELECT x, y, z, a, b, c, id FROM job_query LIMIT 50000;")))
	{
		PrintSQLError(hDB);
		delete hQuery;
		return;
	}

	float flPos[3],	flAngles[3], flHitPosition[3];
	int iMaxId = 0;

    //TRANSATIONS
    /*
    DBResultSet hQueryCommit = null; //
    if (!(hQueryCommit = SQL_Query(hDB, "BEGIN;")))
	{
		PrintSQLError(hDB);
		delete hQueryCommit;
		return;
	}
*/
	static DBStatement s_hStmt = null;
	s_hStmt = null;

    int irowCount = 0;
    int itimeStart = GetTime();
    float fTime = GetEngineTime();

    int iBulkSize = 300;

    float[] faBulkSQL =  new float[iBulkSize*6];
    //char cBulkSQL[100];
    //float faBulkSQL[100];

    int iBulkSQLSize = iBulkSize*14+50+20;// +20 just for sure
    char[] cBulkSQL = new char[iBulkSQLSize];
    //cBulkSQL = new char[iBulkSQLSize];
    // ",(?,?,?,?,?,?)" len 14
    // "INSERT INTO job_done (x, y, z, hx, hy, hz) VALUES" len 50

    StrCat(cBulkSQL,iBulkSQLSize, "INSERT INTO job_done (x, y, z, hx, hy, hz) VALUES ");
    IntToString(iBulkSQLSize,tmp,10);
	//LogMessage(tmp);
   //LogMessage(cBulkSQL);

    iBulkSize = iBulkSize*6;

    int iInx=0;

	char cError[255];
    bool bFlag = true;
	while (bFlag)
	{


	    bFlag = hQuery.FetchRow();

        // added IF for case if there all rows processed, but some unsended data left

        if(bFlag)
        {
            //StrCat(test,8000,"s");
            //LogMessage(test);


            //if (itimeStart < ( GetTime() - 8 ) )


            irowCount = irowCount + 1;
            flPos[0] = hQuery.FetchFloat(0);
            flPos[1] = hQuery.FetchFloat(1);
            flPos[2] = hQuery.FetchFloat(2);
            flAngles[0] = hQuery.FetchFloat(3);
            flAngles[1] = hQuery.FetchFloat(4);
            flAngles[2] = hQuery.FetchFloat(5);

            int iId = hQuery.FetchInt(6);
		    if (iId > iMaxId)
			    iMaxId = iId;

            /*
            if (!s_hStmt)
                s_hStmt = SQL_PrepareQuery(hDB, "INSERT INTO job_done (x, y, z, hx, hy, hz) VALUES (?, ?, ?, ?, ?, ?);", cError, sizeof(cError));
            if (!s_hStmt)
            {
                LogError("Failed to create statement (error: %s)", cError);
                break; //Выходим из цикла и очищаем все, что обработали уже
            }
            */

            //if (!Trace(flPos, flAngles, flHitPosition))
            {
                /*
                s_hStmt.BindFloat(0, flPos[0]);
                s_hStmt.BindFloat(1, flPos[1]);
                s_hStmt.BindFloat(2, flPos[2]);
                s_hStmt.BindFloat(3, flHitPosition[0]);
                s_hStmt.BindFloat(4, flHitPosition[1]);
                s_hStmt.BindFloat(5, flHitPosition[2]);
                */


                //LogMessage("<+= HIT =+>!");
            }
            if (!Trace(flPos, flAngles, flHitPosition))
            //else
            {
                //mark with "10" to detect infinity hit
                //mark with "100" direction of vector
                if(FloatAbs(flAngles[0]-0)<1)
                {
                    if(FloatAbs(flAngles[1]-0)<1)
                    {
                        flHitPosition[0] = flPos[0]+100 ;
                        flHitPosition[1] = flPos[1]+10 ;
                        flHitPosition[2] = flPos[2]+10 ;
                    } else
                    if(FloatAbs(flAngles[1]-180)<1)
                    {
                        flHitPosition[0] = flPos[0]-100 ;
                        flHitPosition[1] = flPos[1]+10 ;
                        flHitPosition[2] = flPos[2]+10 ;
                    } else
                    if(FloatAbs(flAngles[1]-90)<1)
                    {
                        flHitPosition[0] = flPos[0]+10 ;
                        flHitPosition[1] = flPos[1]+100 ;
                        flHitPosition[2] = flPos[2]+10 ;
                    } else
                    if(FloatAbs(flAngles[1]+90)<1)
                    {
                        flHitPosition[0] = flPos[0]+10 ;
                        flHitPosition[1] = flPos[1]-100 ;
                        flHitPosition[2] = flPos[2]+10 ;
                    }
                } else
                if(FloatAbs(flAngles[0]+90)<1)
                {
                        flHitPosition[0] = flPos[0]+10 ;
                        flHitPosition[1] = flPos[1]+10 ;
                        flHitPosition[2] = flPos[2]+100 ;
                } else
                if(FloatAbs(flAngles[0]-90)<1)
                {
                        flHitPosition[0] = flPos[0]+10 ;
                        flHitPosition[1] = flPos[1]+10 ;
                        flHitPosition[2] = flPos[2]-100 ;
                }
                /*
                s_hStmt.BindFloat(0, flPos[0]);
                s_hStmt.BindFloat(1, flPos[1]);
                s_hStmt.BindFloat(2, flPos[2]);
                s_hStmt.BindFloat(3, flHitPosition[0]);
                s_hStmt.BindFloat(4, flHitPosition[1]);
                s_hStmt.BindFloat(5, flHitPosition[2]);
                */
                //LogMessage("No hit.");
            }

            //IntToString(iInx,tmp,10);
            //LogMessage(tmp);
            //IntToString(iBulkSize,tmp,10);
            //LogMessage(tmp);
            faBulkSQL[iInx+0] = flPos[0];
            faBulkSQL[iInx+1] = flPos[1];
            faBulkSQL[iInx+2] = flPos[2];
            faBulkSQL[iInx+3] = flHitPosition[0];
            faBulkSQL[iInx+4] = flHitPosition[1];
            faBulkSQL[iInx+5] = flHitPosition[2];

            //LogMessage("Before Add");
            //IntToString(iBulkSQLSize,tmp,10);
            //LogMessage(tmp);
            //LogMessage("index");
            //IntToString(iInx,tmp,10);
            //LogMessage(tmp);
            //LogMessage(cBulkSQL);
            //LogMessage("iBulkSize");
            //IntToString(iBulkSize,tmp,10);
            //LogMessage(tmp);


            if(iInx==0)
            {
               StrCat(cBulkSQL,iBulkSQLSize,"(?,?,?,?,?,?)");
            }
            else
            {
               StrCat(cBulkSQL,iBulkSQLSize,",(?,?,?,?,?,?)");
            }
            //LogMessage(cBulkSQL);
            //LogMessage("StrLen");
            int len;
            //len = strlen(cBulkSQL);
            //IntToString(len,tmp,10);
            //LogMessage(tmp);

            //LogMessage("After Add");
            //LogMessage(cBulkSQL);
            //LogMessage("BULK ARRAY SIZE");

            iInx = iInx + 6;
		}



       // LogMessage("before if");

		if( ( iInx >= iBulkSize ) || // bulk if full
		    ( fTime < ( GetEngineTime() - 6 ) ) || // timeout is near
		    ( (!bFlag) && iInx > 0 )  // end of loop but still some data need to send
		  )

		    {
		        //LogMessage("if 01");
                if (iInx==0) // break if entered from time but no data to process
                {
                   //LogMessage("Breaking loop");
                    break;
                }


               //LogMessage("Prepare");

                //LogMessage(cBulkSQL);
                if(s_hStmt)
                {
                    delete s_hStmt;
                    s_hStmt = null;
                }


                s_hStmt = SQL_PrepareQuery(hDB, cBulkSQL, cError, sizeof(cError));
                if (!s_hStmt)

                {
                    LogError("Failed to create statement (error: %s)", cError);
                    break; //Выходим из цикла и очищаем все, что обработали уже
                }
               //LogMessage("After prepare");

                for(int i=0;i<iInx;i++)
                {
                    s_hStmt.BindFloat(i, faBulkSQL[i]);
                }
               //LogMessage("After bind loop");

                if (!SQL_Execute(s_hStmt))
                {
                    if (SQL_GetError(s_hStmt, cError, sizeof(cError)))
                        LogError("Failed to query statement (error: %s)", cError);
                    break; //Выходим из цикла и очищаем все, что обработали уже
                }


               //LogMessage("After execute");

                iInx = 0;
                Format(cBulkSQL, iBulkSQLSize, "INSERT INTO job_done (x, y, z, hx, hy, hz) VALUES",iInx ); //cheat to write to char[]

               //LogMessage("After replace");

               //LogMessage("Reset");

		       //LogMessage(cBulkSQL);


		}
		/*
	    if (fTime < ( GetEngineTime() - 6 ) )
	    {
	       //LogMessage("Exiting before full process");
	        break;
	    }
	    */

	}


   //LogMessage("timer");
    /*
	if (!(hQueryCommit = SQL_Query(hDB, "COMMIT;")))
	{
		PrintSQLError(hDB);
		delete hQuery;
		return;

	}
	*/

    if(irowCount > 0)
    {
        char mesg[100];
        Format(mesg, 100, "Processed: %i rows for %i secound", irowCount,GetTime() - itimeStart);
        IntToString(irowCount,mesg,10);
        LogMessage("Rows processed: ",irowCount);
        LogMessage(mesg);
	}

	delete hQuery;
	if (iMaxId)
	{
	    char cError[255];

		s_hStmt = null;
		s_hStmt = SQL_PrepareQuery(hDB, "DELETE FROM `job_query` WHERE `id` <= ?;", cError, sizeof(cError));
		if (!s_hStmt)
		{
			LogError("Failed to create statement (error: %s)", cError);

		}
		else{
		    s_hStmt.BindInt(0, iMaxId);
		    if (!SQL_Execute(s_hStmt))
		    {
			    if (SQL_GetError(s_hStmt, cError, sizeof(cError)))
				    LogError("Failed to query statement (error: %s)", cError);
    		}
	    	}
		delete s_hStmt;
		char s[256];
		float calc;
		calc = (GetEngineTime()-fTime)*1000/irowCount;
		Format(s, 256, "Time per 1k: %f", calc);
		LogMessage(s);
        //char cDelQuery[128];
		//Format(cDelQuery, 128, "DELETE FROM `job_query` WHERE `id` <= %i;", iMaxId);
		//if (!SQL_FastQuery(hDB, cDelQuery, iMaxId))
		//    LogError(cDelQuery);
		//	PrintSQLError(hDB);
	}
}
