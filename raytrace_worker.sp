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

char cBuffer[24];
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
    SocketSetOption(hSocket, CallbacksPerFrame, 100000);
    SocketSetOption(hSocket, ForceFrameLock, false);
    //SocketSetOption(hSocket, ConcatenateCallbacks, 24*10000);
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

void RayDecode(char[] buffer,int startPos, float[3] pos, float[3] angle)
{
    int iTmp;
    int k = 0;
    for (int i = startPos; i < startPos + 24; i += 4)
    {
        iTmp = buffer[i + 0];
        iTmp = iTmp << 8;
        iTmp = buffer[i + 1] + iTmp;
        iTmp = iTmp << 8;
        iTmp = buffer[i + 2] + iTmp;
        iTmp = iTmp << 8;
        iTmp = buffer[i + 3] + iTmp;

        if (i < (startPos + 12))
        {
            pos[k] = view_as<float>(iTmp);
        }
        else
        {
            angle[k] = view_as<float>(iTmp);
        }
        k++;
        if (k==3)
        {
            k=0;
        }
    }
}

void RayEncode(char[] buffer,int startPos, float[3] pos, float[3] hit)
{
    int iTmp;
    for (int i = 0; i < 6; i++)
    {
        if (i < 3)
        {
            iTmp = view_as<int>(pos[i]);
        }
        else
        {
            iTmp = view_as<int>(hit[i-3]);
        }
        buffer[startPos + i*4 + 3] = view_as<char>(iTmp & 255);
        iTmp = iTmp  >> 8;
        buffer[startPos + i*4 + 2] = view_as<char>(iTmp & 255);
        iTmp = iTmp  >> 8;
        buffer[startPos + i*4 + 1] = view_as<char>(iTmp & 255);
        iTmp = iTmp  >> 8;
        buffer[startPos + i*4 + 0] = view_as<char>(iTmp & 255);
    }
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

        char tmp[100];
        LogMessage("iBufSize");
        IntToString(iBufSize,tmp,10);
        LogMessage(tmp);
    */
       // char tmp[100];
       // LogMessage("dataSize");
       //  IntToString(dataSize,tmp,10);
       // LogMessage(tmp);

    // dump data to file

    int temp[1];
    for (int i=0; i < dataSize; i++){
        if (iterator_read < 12){
            temp[0] = receiveData[i];
            WriteFile(hFileInput, temp, 1, 1);
        }
        iterator_read = iterator_read + 1;
        if (iterator_read == 24){
            iterator_read = 0;
        }
    }
    FlushFile(hFileInput);


    char[] c_output = new char[dataSize+24];
    //char[] c_input = new char[dataSize+24];
    int i = 0;
    int i_output_size = 0;

    float flPoint[3];
    float flAngle[3];
    float flHit[3];

    while (i < dataSize){
        cBuffer[iBufSize] = receiveData[i];
        i++;
        iBufSize++;
        if (iBufSize == 24){
            iBufSize = 0;
            RayDecode(cBuffer, 0, flPoint, flAngle);
            if (!Trace(flPoint, flAngle, flHit)){
                continue;
            }
            RayEncode(c_output, i_output_size, flPoint, flHit);
            i_output_size += 24;

        }
    }

    // dump data to file

    for (int i=0; i < i_output_size; i++){
        if (iterator_write < 12){
            temp[0] = c_output[i];
            WriteFile(hFileWrite, temp, 1, 1);
        }
        iterator_write = iterator_write + 1;
        if (iterator_write == 24){
            iterator_write = 0;
        }
    }
    FlushFile(hFileWrite);


    if(i_output_size > 0){
        SocketSend(socket, c_output, i_output_size);
    }
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
    Handle hTrace = TR_TraceRayEx(flPos, flAngles, MASK_SOLID & ~ CONTENTS_MONSTER /*CONTENTS_SOLID*/ /*MASK_VISIBLE*/, RayType_Infinite);

    if (TR_DidHit(hTrace)) {
        TR_GetEndPosition(flEnd, hTrace);
        if(TR_PointOutsideWorld(flEnd)){
            delete hTrace;
            return false;
        }
        delete hTrace;
        return true;
    } else {
    /*
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
        */
        delete hTrace;
        return false;
    }
}

