#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <netdb.h>

struct in_addr NetGetAddr(char *hname)
{
    struct sockaddr_in addr;
    struct hostent *hent;
    
    hent = gethostbyname(hname);
    if (hent == NULL)
	addr.sin_addr.s_addr = inet_addr(hname);
    else
	memcpy(&addr.sin_addr, hent->h_addr, hent->h_length);
    return addr.sin_addr;
}

int main(int argc, char **argv)
{
    FILE *fp;
    int clientId, uniqueId, sz, len;
    //char *srcip = NULL;
    
    if (argc != 2) {
	fprintf(stderr, "usage: readoutfile filename\n");
	exit(1);
    }

    fp = fopen(argv[1], "r");
    for (int i=0; i<strlen(argv[1]); i++) {
	if (strncmp(argv[1] + i, "trace.out.", 10) == 0) {
	    //srcip = argv[1] + i + 10;
	    break;
	}
    }
    //assert(srcip != NULL);
    //if (*srcip < '0' || *srcip > '9') {
	//srcip = strdup(inet_ntoa(NetGetAddr(srcip)));
	//assert (*srcip >= '0' && *srcip <= '9');
    //}

    while (1) {
	int ret = fread(&clientId, sizeof(int), 1, fp);
	if (ret != 1)
	    break;
	fread(&uniqueId, sizeof(int), 1, fp);
	fread(&sz, sizeof(int), 1, fp);
	fread(&len, sizeof(int), 1, fp);

	/*	printf("read %d records (%d bytes) from %d %d\n", sz, len, clientId, uniqueId); */
	for (int i=0; i<sz; i++) {
	    struct in_addr ip;
	    int hops;
	    int ttl;
	    float curr;
	    fread(&ip, sizeof(struct in_addr), 1, fp);
	    fread(&hops, sizeof(int), 1, fp);
	    //printf("%s %s", srcip, inet_ntoa(ip));
	    for (int j=0; j<hops; j++) {
		float lat;
		fread(&ip, sizeof(struct in_addr), 1, fp);
		fread(&lat, sizeof(float), 1, fp);
		fread(&ttl, sizeof(int), 1, fp);
		if (ip.s_addr == 0)
		    printf(" *");
		else
		    printf(" %u %f %d", ip.s_addr, lat, ttl);
	    }
	    printf("\n");
	}
    }
}
