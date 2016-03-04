######################################################################
# create the blob, return name of object in pgobj table, store file in
# blobpath

createBlob <- function(obj=NA,fname=NA,name=NA,kv=NA,
					   description="",textfile=NA, 
					   blobpath=getOption("pgobj.blobs")) {

	#################################################################
	# options:
	# obj: object containing blob
	# fname: filename of blob (e.g. grid). obj & filename mutually
	# exclusive
	# kv: list with key-value pairs: list(key1="value",key2="value2")
	# description: string containing short description
	# text file: text file with longer description (can be NA)
	# blobpath: path to store blob data

	# obj or fname, and name, path should not be empty

	# blob obj is stored with 'name.blob' in database, standard overwrite rules
	# obj is stored in path with name.rds, together with ini file:
	# name.ini


	#################################################################
	# blob function should be fool proof, so do thorough testing of
	# input values, give verbose error messages.

	if(is.null(blobpath)){
	   stop("option pgobject.blobpath does not exist or blobpath is not set")
	}

	if(!is.character(blobpath)) {
		stop("blobpath is not character")
	}


	if(!is.na(obj)&&!is.na(fname)) {
		stop("obj and fname mutually exclusive options")
	}

	if(is.na(obj)&&is.na(fname)) {
		stop("obj and fname are empty")
	}

	if(!is.na(fname)&&!is.character(fname)) {
		stop("fname is not character")
	}

	if(is.na(name)) {
		stop("name is empty")
	}

	if(!is.na(name)&&!is.character(name)) {
		stop("name is not character")
	}

	if(!is.na(kv)&&!is.list(kv)) {
		stop("kv is not a list")
	}

	if(!is.character(description)) {
		stop("description is not character")
	}

	if(!is.na(fname)&&!is.character(fname)) {
		stop("fname is not character")
	}
	if(!is.na(fname)&&!file.exists(fname)) {
		stop("fname does not exists")
	}


	if(!is.na(textfile)&&!is.character(textfile)) {
		stop("textfile is not character")
	}

	if(!is.na(textfile)&&!file.exists(textfile)) {
		stop(paste("textfile",textfile,"does not exists"))
	}

	# check names of kv
	kv.names <- names(kv)
	if(is.null(kv.names)) {
		stop("kv list does not contain key values")
	}

	for (i in kv.names) {
		if(i=="") {
			stop(paste("kv list does not contain key values for key",i))
		}
		val=kv[[i]]
		if(!is.character(val)) {
			stop(paste("kv list is not character does not contain
					   character value for key",i))
		}
		if(val=="") {
			stop(paste("kv list does not contain value values for key",i))
		}
	}

	if(length(fname)>1) {
		stop("barf")
	}

	#################################################################
	# so now the input data is validated, let's do stuff
	# check if we deal with a file or an object
	if(is.na(fname)) {
		# it's an object
		fname <- paste(name,".rds",sep="")
		isObject <- TRUE
	} else {
		isObject <- FALSE
	}

	# test if file allready exists, if so, exit
	fpath <- paste(blobpath,basename(fname),sep='/')
	cat("storing blob: ",fpath,"\n")
	if(file.exists(fpath)) {
		stop(paste("blob file allready exists:",fpath))
	}

	# test if blob path is writable 
	if(!file.create(fpath)) {
		stop(paste("cannot write blobfile:",fpath))
	} else {
		file.remove(fpath)
	}

	# it is an object store it as in rds file, else copy file
	if(isObject) {
		saveRDS(obj,fpath)
	} else {
		# it's a file, so just copy
		file.copy(fname,fpath)
	}


	# read textfile, if exists
	if(!is.na(textfile)) {
		connection <- file(textfile)
		txtcontent<- readLines(connection)
		close(connection)
	} else {
		txtcontent <- description
	}


	#################################################################
	# create blobobject, it's a list with all the info, except the
	# data. Do not overwrite existing objects, they can run out of
	# sync. 

	md5 <- getmd5(fpath)

	blobobj <- list(fname=basename(fpath),path=blobpath,kv=kv,
					description=description,md5=md5,
					text=txtcontent,isObject=isObject)

	#store the blob object to the database, including meta data.
	storeObj(name,blobobj)
	 for (i in names(kv)) {
		 storeKeyval(obj=name,key=i,val=kv[[i]],overwrite=TRUE)
	 }
	storeKeyval(obj=name,key="md5",val=as.character(md5),overwrite=TRUE)

	# create meta-object: and object with meta data. Store this data
	#	in the database and also in a human readable ini file

	# first create metaobj
	meta <- data.frame(section="meta",key="src",value=name)
	meta <- rbind(meta,data.frame(section="meta",
								  key="summary",value=description))
	metakv <- cbind(section="object",getKeyvalObj(name))
	meta <- rbind(meta,metakv)
	metaobj <- list(kv=meta,text=txtcontent)
	
	# then write ini file
	ini <- write.ini(metaobj)
	inifile <- paste(fpath,"ini",sep=".")
	f<-file(inifile,"w") 
	cat(ini,file=f,sep="\n")
	close(f)

	#################################################################
	# return object
	return(blobobj)
}

