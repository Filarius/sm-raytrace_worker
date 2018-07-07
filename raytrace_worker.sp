#pragma semicolon 1

#define DEBUG

#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>
#include <socket>

//pragma newdecls required

ConVar g_hDBName = null;
Database g_hDatabase = null;

char cBuffer[1024000];
int iBufSize = 0;

File hFileWrite;
File hFileInput;



public Plugin myinfo = 
{
	name = "Raytracer worker",
	author = "Filarius",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://github.com/Filarius/sm-raytrace_worker"
};

ConVar SocketPort;

public void OnPluginStart()
{
	g_hDBName = CreateConVar("sm_filarius_dbname", "default", "name of the database to use");
	SocketPort = CreateConVar("sm_socket_port", "40000", "socket port to use");
	SocketSetOption(INVALID_HANDLE, DebugMode, 1);
    DeleteFile("source.txt",false,"");
    hFileWrite = OpenFile("server_output.txt","wb");
    hFileInput = OpenFile("server_input.txt","wb");
	PrintToServer("Plugin loaded.");
}

Handle hSocket;

public void OnPluginEnd()
{
    CloseHandle(hSocket);
    CloseHandle(hFileWrite);
    CloseHandle(hFileInput);
}



public void OnConfigsExecuted()
{
	char cDBName[64];
	g_hDBName.GetString(cDBName, 64);
	//Database.Connect(SQL_ConnectToDatabase, cDBName);

	int iSocketPort = GetConVarInt(SocketPort);

	hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetOption(hSocket, SocketSendLowWatermark, 24);
	SocketSetOption(hSocket, SocketReceiveLowWatermark, 24);
	SocketSetOption(hSocket, CallbacksPerFrame, 1);
    //SocketSetOption(hSocket, ConcatenateCallbacks, 24*1000);
	//SocketSetOption(hSocket, SocketSendBuffer, 24*5);
	//SocketSetOption(hSocket, SocketReceiveBuffer, 24*5);
	//SocketSetOption(hSocket, SocketReceiveTimeout, 1);
	//SocketSetOption(hSocket, SocketSendTimeout, 1);
	SocketSetOption(hSocket, ForceFrameLock, false);
	SocketBind(hSocket, "0.0.0.0", iSocketPort);
	SocketListen(hSocket, OnSocketIncoming);
}


public  OnSocketIncoming(Handle socket, Handle newSocket, char[] remoteIP, int remotePort, int arg)
{
	PrintToServer("%s:%d connected", remoteIP, remotePort);
	SocketSetReceiveCallback(newSocket, OnChildSocketReceive);
	SocketSetDisconnectCallback(newSocket, OnChildSocketDisconnected);
	SocketSetErrorCallback(newSocket, OnChildSocketError);
}


//public void OnSocketError(Handle socket, int errorType, int errorNum, int arg)
public  OnSocketError(Handle:socket, const errorType, const errorNum, any:arg)
{ 

	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}


void RayDecode(char[] buffer,int startPos, float[3] pos, float[3] angle,float[3] hit)
{
    //TODO
}

void RayEncode(char[] buffer,int startPos, float[3] pos, float[3] angle,float[3] hit)
{
    //TODO
}

void CheckNan(float f)
{
    if (f != f)
    {
        LogMessage("NAN!");
    }
}


public OnChildSocketReceive(Handle socket, char[] receiveData, int dataSize, int hFile)
{
    /* Snipet
    LogMessage("iBufSize");
    IntToString(iBufSize,tmp,10);
    LogMessage(tmp);
    */
	char tmp[10];
	int pointer = 0;




	//if( pointer < ( iBufSize + dataSize ) )// iBufSize >= 24 ) // have all bulk data received
	{
	    int iPackSize = (iBufSize + dataSize) / 24 ;
	    float[] flHits = new float[iPackSize*6];
	    int iHitsCount;

	    for(int i=0;i<iPackSize;i++) // iterate rays
	    {

	        char chunk[24];

	        if (pointer < iBufSize)
	        {
	            for(int k=0;k<iBufSize;k++)
	            {
	                chunk[k] = cBuffer[k];
	            }

	            for(int k=0; k<24-iBufSize; k++)
	            {
	                chunk[iBufSize + k] = receiveData[k];
	            }

	        }
	        else
	        {
	            for(int k=0;k<24;k++)
	            {
	                chunk[k] = receiveData[pointer-iBufSize+k];
	            }

	        }
	        pointer += 24;
	        int shift = 0;
            float flRay[6];
	        for(int j=0;j<6;j++) // iterate floats
	        {
	            int jShift = j*4;
	            int iVal = 0;
	            iVal = chunk[shift + (jShift + 0)];
	            iVal = iVal << 8;
	            iVal = chunk[shift + (jShift + 1)] + iVal;
	            iVal = iVal << 8;
	            iVal = chunk[shift + (jShift + 2)] + iVal;
	            iVal = iVal << 8;
	            iVal = chunk[shift + (jShift + 3)] + iVal;
	            flRay[j] = view_as<float>(iVal);
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

	        //DEBUG
	        int sendString[24];
            for(int k=0;k<24;k++)
            {
                sendString[k] = chunk[k];
            }
            //WriteFile(hFileInput, sendString, 24,1);
            WriteFile(hFileInput, sendString, 12,1);

            if (!Trace(flPoint,flAngle,flHit))
            {
                continue;
            }

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

	    char[] cSendBuff= new char[iHitsCount*24];
	    int iSendBuffPos = 0;
	    for(int i=0;i<iHitsCount;i++) //iterate ray results
	    {

	        int shift = i*6;
	        for(int j=0;j<6;j++) //iterate floats
	        {
                //CheckNan(flHits[shift + j]);
	            int iTmp = view_as<int>(flHits[shift + j]);
	            cSendBuff[iSendBuffPos+3] = view_as<char>(iTmp  & 255);
	            iTmp = iTmp  >> 8;
	            cSendBuff[iSendBuffPos+2] = view_as<char>(iTmp  & 255);
	            iTmp = iTmp  >> 8;
	            cSendBuff[iSendBuffPos+1] = view_as<char>(iTmp  & 255);
	            iTmp = iTmp  >> 8;
	            cSendBuff[iSendBuffPos+0] = view_as<char>(iTmp  & 255);
	            iSendBuffPos += 4;

	        }



	        int sendString[24];
            for(int k=0;k<24;k++)
            {
                sendString[k] = cSendBuff[k+iSendBuffPos-24];
            }

            WriteFile(hFileWrite, sendString, 12,1);


	    }

        //remember tail of received data to use as head for next run
        iBufSize = (iBufSize + dataSize) - iPackSize*24;


        for(int i = 0; i<iBufSize; i++)
        {
            cBuffer[i] = receiveData[iPackSize*24 + i];
        }

/*
        int[] sendString = new int[iSendBuffPos];
        for(int i = 0; i<iSendBuffPos; i++)
        {
            sendString[i] = cSendBuff[i];
        }

        WriteFile(hFileWrite, sendString, iSendBuffPos,1);

*/
	    FlushFile(hFileWrite);

	    //chunking output buffer
	    /*
	    while(iSendBuffPos > 0)
	    {
	        int size = 1024;
	        if (size > iSendBuffPos)
	        {
	            size = iSendBuffPos;
	        }
	        SocketSend(socket,cSendBuff, size);
	        iSendBuffPos = iSendBuffPos - size;
	        for(int i=0;i<iSendBuffPos;i++)
	        {
                cSendBuff[i] = cSendBuff[i+size];
	        }

	    }*/
        SocketSend(socket,cSendBuff, iSendBuffPos);


	}

}

public  OnChildSocketDisconnected(Handle socket, int hFile)
{
	// remote side disconnected

	CloseHandle(socket);
}

public  OnChildSocketError(Handle socket, int errorType, int errorNum, any ary)
{
	// a socket error occured

	LogError("child socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}













public void OnMapStart()
{
	//CreateTimer(1.0, Timer_ProcessDB, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
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
		delete hTrace;
		return true;
	}
	else
	{
	    float flHitPosition[3];
	    flHitPosition[0]=1.0;
	    flHitPosition[1]=1.0;
	    flHitPosition[2]=1.0;
	    if(FloatAbs(flAngles[0]-0)<1)
                {
                    if(FloatAbs(flAngles[1]-0)<1)
                    {
                        flHitPosition[0] = flPos[0]+100.0 ;
                        flHitPosition[1] = flPos[1]+10.0 ;
                        flHitPosition[2] = flPos[2]+10.0 ;
                    } else
                    if(FloatAbs(flAngles[1]-180)<1)
                    {
                        flHitPosition[0] = flPos[0]-100.0 ;
                        flHitPosition[1] = flPos[1]+10.0 ;
                        flHitPosition[2] = flPos[2]+10.0 ;
                    } else
                    if(FloatAbs(flAngles[1]-90)<1)
                    {
                        flHitPosition[0] = flPos[0]+10.0 ;
                        flHitPosition[1] = flPos[1]+100.0 ;
                        flHitPosition[2] = flPos[2]+10.0 ;
                    } else
                    if(FloatAbs(flAngles[1]+90)<1)
                    {
                        flHitPosition[0] = flPos[0]+10.0 ;
                        flHitPosition[1] = flPos[1]-100.0 ;
                        flHitPosition[2] = flPos[2]+10.0 ;
                    }
                } else
                if(FloatAbs(flAngles[0]+90)<1)
                {
                        flHitPosition[0] = flPos[0]+10.0 ;
                        flHitPosition[1] = flPos[1]+10.0 ;
                        flHitPosition[2] = flPos[2]+100.0 ;
                } else
                if(FloatAbs(flAngles[0]-90)<1)
                {
                        flHitPosition[0] = flPos[0]+10.0 ;
                        flHitPosition[1] = flPos[1]+10.0 ;
                        flHitPosition[2] = flPos[2]-100.0 ;
                }
        flEnd[0] = flHitPosition[0];
        flEnd[1] = flHitPosition[1];
        flEnd[2] = flHitPosition[2];
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

    int iBulkSQLSize = iBulkSize*14+50+20;// +20 just for sure
    char[] cBulkSQL = new char[iBulkSQLSize];

    StrCat(cBulkSQL,iBulkSQLSize, "INSERT INTO job_done (x, y, z, hx, hy, hz) VALUES ");
    IntToString(iBulkSQLSize,tmp,10);

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


            if (!Trace(flPos, flAngles, flHitPosition))
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

            }


            faBulkSQL[iInx+0] = flPos[0];
            faBulkSQL[iInx+1] = flPos[1];
            faBulkSQL[iInx+2] = flPos[2];
            faBulkSQL[iInx+3] = flHitPosition[0];
            faBulkSQL[iInx+4] = flHitPosition[1];
            faBulkSQL[iInx+5] = flHitPosition[2];

            if(iInx==0)
            {
               StrCat(cBulkSQL,iBulkSQLSize,"(?,?,?,?,?,?)");
            }
            else
            {
               StrCat(cBulkSQL,iBulkSQLSize,",(?,?,?,?,?,?)");
            }
            int len;
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
                    break;
                }

                for(int i=0;i<iInx;i++)
                {
                    s_hStmt.BindFloat(i, faBulkSQL[i]);
                }

                if (!SQL_Execute(s_hStmt))
                {
                    if (SQL_GetError(s_hStmt, cError, sizeof(cError)))
                        LogError("Failed to query statement (error: %s)", cError);
                    break;
                }

                iInx = 0;
                Format(cBulkSQL, iBulkSQLSize, "INSERT INTO job_done (x, y, z, hx, hy, hz) VALUES",iInx ); //cheat to write to char[]

		}

	}


    if(irowCount > 0)
    {
        char mesg[100];
        Format(mesg, 100, "Processed: %i rows in %i secound", irowCount,GetTime() - itimeStart);
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
	}
}
