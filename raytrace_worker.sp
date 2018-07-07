#pragma semicolon 1
#pragma dynamic 409600

#define DEBUG
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>
#include <socket>

ConVar SocketPort;
ConVar g_hDBName = null;
Database g_hDatabase = null;

char cBuffer[2400];
int iBufSize = 0;

File hFileWrite;
File hFileInput;

Handle hSocket;

public Plugin myinfo = {
    name = "Raytracer worker",
    author = "Filarius",
    description = "",
    version = PLUGIN_VERSION,
    url = "https://github.com/Filarius/sm-raytrace_worker"
};

public void OnPluginStart() {
    SocketPort = CreateConVar("sm_socket_port", "40000", "socket port to use");
    SocketSetOption(INVALID_HANDLE, DebugMode, 1);
    DeleteFile("source.txt",false,"");
    hFileWrite = OpenFile("server_output.txt","wb");
    hFileInput = OpenFile("server_input.txt","wb");
    PrintToServer("Plugin loaded.");
}

public void OnPluginEnd() {
    CloseHandle(hSocket);
    CloseHandle(hFileWrite);
    CloseHandle(hFileInput);
}

public void OnConfigsExecuted() {
    int iSocketPort = GetConVarInt(SocketPort);
    hSocket = SocketCreate(SOCKET_TCP, OnSocketError);

    SocketSetOption(hSocket, SocketSendLowWatermark, 24);
    SocketSetOption(hSocket, SocketReceiveLowWatermark, 24);
    SocketSetOption(hSocket, CallbacksPerFrame, 1);
    SocketSetOption(hSocket, ForceFrameLock, false);
    // SocketSetOption(hSocket, ConcatenateCallbacks, 24*1000);
    // SocketSetOption(hSocket, SocketSendBuffer, 24*5);
    // SocketSetOption(hSocket, SocketReceiveBuffer, 24*5);
    // SocketSetOption(hSocket, SocketReceiveTimeout, 1);
    // SocketSetOption(hSocket, SocketSendTimeout, 1);

    SocketBind(hSocket, "0.0.0.0", iSocketPort);
    SocketListen(hSocket, OnSocketIncoming);
}

public OnSocketIncoming(Handle socket, Handle newSocket, char[] remoteIP, int remotePort, int arg) {
    PrintToServer("%s:%d connected", remoteIP, remotePort);
    SocketSetReceiveCallback(newSocket, OnChildSocketReceive);
    SocketSetDisconnectCallback(newSocket, OnChildSocketDisconnected);
    SocketSetErrorCallback(newSocket, OnChildSocketError);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:arg) { 
    LogError("socket error %d (errno %d)", errorType, errorNum);
    CloseHandle(socket);
}

void RayDecode(char[] buffer,int startPos, float[3] pos, float[3] angle,float[3] hit) {
    //TODO
}

void RayEncode(char[] buffer,int startPos, float[3] pos, float[3] angle,float[3] hit) {
    //TODO
}

void CheckNan(float f) {
    if (f != f) {
        LogMessage("NAN!");
    }
}

int iterator_read = 0;
int iterator_write = 0;

public OnChildSocketReceive(Handle socket, char[] receiveData, int dataSize, int hFile) {
    /*
        Snippet

        LogMessage("iBufSize");
        IntToString(iBufSize,tmp,10);
        LogMessage(tmp);

    */
    char tmp[100];
    int temp[1];

    for (int i=0; i < dataSize; i++)
    {
        if (iterator_read < 12){
            temp[0] = receiveData[i];
            WriteFile(hFileInput, temp, 1, 1);
        }
        iterator_read = iterator_read + 1;
        if (iterator_read == 24)
        {
            iterator_read = 0;
        }
    }
    FlushFile(hFileInput);


    int pointer = 0;
    int iPackSize = (iBufSize + dataSize) / 24;

    float[] flHits = new float[iPackSize*6];
    int iHitsCount;

    // iterate over chunks
    for (int i=0; i < iPackSize; i++) {
        char chunk[24];
        float flRay[6];

        if (pointer < iBufSize) {
            for (int k=0; k < iBufSize; k++) {
                chunk[k] = cBuffer[k];
            }

            for (int k=0; k < 24 - iBufSize; k++) {
                chunk[iBufSize + k] = receiveData[k];
            }
        } else {
            for (int k=0; k < 24; k++) {
                chunk[k] = receiveData[pointer - iBufSize + k];
            }
        }

        pointer += 24;

        // iterate floats
        for (int j=0; j < 6; j++) {
            int jShift = j * 4;
            int iVal = 0;

            iVal = chunk[jShift + 0];
            iVal = iVal << 8;
            iVal = chunk[jShift + 1] + iVal;
            iVal = iVal << 8;
            iVal = chunk[jShift + 2] + iVal;
            iVal = iVal << 8;
            iVal = chunk[jShift + 3] + iVal;
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

        // DEBUG
        int sendString[24];

        for (int k = 0; k < 24; k++) {
            sendString[k] = chunk[k];
        }

        // 12 bytes contain only start positions 
        //WriteFile(hFileInput, sendString, 12, 1);

        if (!Trace(flPoint, flAngle, flHit)){
            continue;
        }

        int iHitsPos = iHitsCount * 6;

        flHits[iHitsPos + 0] = flPoint[0];
        flHits[iHitsPos + 1] = flPoint[1];
        flHits[iHitsPos + 2] = flPoint[2];
        flHits[iHitsPos + 3] = flHit[0];
        flHits[iHitsPos + 4] = flHit[1];
        flHits[iHitsPos + 5] = flHit[2];

        iHitsCount += 1;
    }
    // encode results

    char[] cSendBuff= new char[iHitsCount*24];
    int iSendBuffPos = 0;

    // iterate ray results
    for (int i=0; i < iHitsCount; i++) {
        int shift = i*6;

        // iterate floats
        for (int j = 0; j < 6; j++) {
            // NaN check performed on client
            // CheckNan(flHits[shift + j]);

            int iTmp = view_as<int>(flHits[shift + j]);
            cSendBuff[iSendBuffPos + 3] = view_as<char>(iTmp & 255);
            iTmp = iTmp  >> 8;
            cSendBuff[iSendBuffPos + 2] = view_as<char>(iTmp & 255);
            iTmp = iTmp  >> 8;
            cSendBuff[iSendBuffPos + 1] = view_as<char>(iTmp & 255);
            iTmp = iTmp  >> 8;
            cSendBuff[iSendBuffPos + 0] = view_as<char>(iTmp & 255);
            iSendBuffPos += 4;
        }
        /*

        int sendString[24];

        for (int k=0; k < 24; k++) {
            sendString[k] = cSendBuff[k + iSendBuffPos - 24];
        }

        WriteFile(hFileWrite, sendString, 12,1);*/
    }

    // save tail of received data to use as head in next run
    iBufSize = (iBufSize + dataSize) - iPackSize*24;

    for(int i = 0; i < iBufSize; i++) {
        cBuffer[i] = receiveData[iPackSize * 24 + i];
    }

    //FlushFile(hFileWrite);

    for (int i=0; i < iSendBuffPos; i++)
    {
        if (iterator_write < 12){
            temp[0] = cSendBuff[i];
            WriteFile(hFileWrite, temp, 1, 1);
        }
        iterator_write = iterator_write + 1;
        if (iterator_write == 24)
        {
            iterator_write = 0;
        }
    }
    FlushFile(hFileWrite);

    SocketSend(socket,cSendBuff, iSendBuffPos);
}

public OnChildSocketDisconnected(Handle socket, int hFile) {
    CloseHandle(socket);
}

public OnChildSocketError(Handle socket, int errorType, int errorNum, any ary) {
    LogError("socket error %d (errno %d)", errorType, errorNum);
    CloseHandle(socket);
}

bool Trace(float flPos[3], float flAngles[3], float flEnd[3]) {
    //Нам же нужно сделать модель, она по логике должна содержать ток видимые части
    Handle hTrace = TR_TraceRayEx(flPos, flAngles, MASK_VISIBLE, RayType_Infinite); 

    if (TR_DidHit(hTrace)) {
        TR_GetEndPosition(flEnd, hTrace);
        delete hTrace;
        return true;
    } else {
        float flHitPosition[3];
        flHitPosition[0]=1.0;
        flHitPosition[1]=1.0;
        flHitPosition[2]=1.0;
        if (FloatAbs(flAngles[0]-0)<1) {
            if (FloatAbs(flAngles[1]-0)<1) {
                flHitPosition[0] = flPos[0] + 100.0;
                flHitPosition[1] = flPos[1] + 10.0;
                flHitPosition[2] = flPos[2] + 10.0;

            } else if(FloatAbs(flAngles[1] - 180) < 1) {
                flHitPosition[0] = flPos[0] - 100.0;
                flHitPosition[1] = flPos[1] + 10.0;
                flHitPosition[2] = flPos[2] + 10.0;

            } else if(FloatAbs(flAngles[1] - 90) < 1) {
                flHitPosition[0] = flPos[0] + 10.0;
                flHitPosition[1] = flPos[1] + 100.0;
                flHitPosition[2] = flPos[2] + 10.0;

            } else if(FloatAbs(flAngles[1] + 90) < 1) {
                flHitPosition[0] = flPos[0] + 10.0;
                flHitPosition[1] = flPos[1] - 100.0;
                flHitPosition[2] = flPos[2] + 10.0;
            }
        } else if(FloatAbs(flAngles[0] + 90) < 1) {
            flHitPosition[0] = flPos[0] + 10.0;
            flHitPosition[1] = flPos[1] + 10.0;
            flHitPosition[2] = flPos[2] + 100.0;

        } else if(FloatAbs(flAngles[0]-90)<1) {
            flHitPosition[0] = flPos[0] + 10.0;
            flHitPosition[1] = flPos[1] + 10.0;
            flHitPosition[2] = flPos[2] - 100.0;
        }

        flEnd[0] = flHitPosition[0];
        flEnd[1] = flHitPosition[1];
        flEnd[2] = flHitPosition[2];

        delete hTrace;
        return false;
    }
}

