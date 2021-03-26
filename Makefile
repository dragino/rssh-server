### Application-specific constants
APP_NAME := rssh_serv

### Environment constants 

ARCH ?=
CROSS_COMPILE ?=
CC := $(CROSS_COMPILE)gcc
AR := $(CROSS_COMPILE)ar

LCFLAGS = $(CFLAGS) -fPIC  -I. 

OBJDIR = obj

INCLUDES = $(wildcard *.h)

### linking options

LLIBS := -lsqlite3 -lpthread 

### general build targets

all: $(APP_NAME)  rssh_cli

clean:
	rm -f $(OBJDIR)/*.o
	rm -f $(APP_NAME) rssh_cli

### Sub-modules compilation

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/%.o: %.c $(INCLUDES) | $(OBJDIR)
	$(CC) -c $(LCFLAGS) $< -o $@

rssh_cli: $(OBJDIR)/rssh_client.o
	$(CC) -fPIE  $^ -o $@ $(LLIBS)

### Main program compilation and assembly
$(APP_NAME): $(OBJDIR)/db.o $(OBJDIR)/network.o $(OBJDIR)/rssh_serv.o
	$(CC) -fPIE  $^ -o $@ $(LLIBS)

### EOF
