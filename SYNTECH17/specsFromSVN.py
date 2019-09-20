import os
import sys
import pysvn
from shutil import copyfile

svn_url = "https://smlab.unfuddle.com/svn/smlab_workshopclass/"
repo_path = "./workshop17"
specs_path = "./SYNTECH17"
client = pysvn.Client(repo_path)
headrev = pysvn.Revision(pysvn.opt_revision_kind.head)
currrev = pysvn.Revision(pysvn.opt_revision_kind.working)
specs_groups = ['group1','group2','group3','group4','group5']

def get_login(realm, username, may_save):
    svn_user = "your_username"
    svn_pass = "your_password"
    return True, svn_user, svn_pass, False

def ssl_server_trust_prompt(trust_dict):
    retcode = True
    accepted_failures = trust_dict['failures']
    save = True
    return retcode, accepted_failures, save

def set_client():
    client.callback_ssl_server_trust_prompt = ssl_server_trust_prompt
    client.callback_get_login = get_login

def get_revision():
    revlog = client.log(repo_path,revision_start=currrev, \
                        revision_end=currrev, discover_changed_paths=False)
    return revlog[0].revision.number
    
def checkout():
    set_client()
    rev = headrev
    return client.checkout(svn_url, repo_path, recurse=True, revision=rev)

def update_to_rev(rev):
    print("update_to_rev rev = %s" % rev)
    return client.update(repo_path, recurse=True,
                         revision=pysvn.Revision(pysvn.opt_revision_kind.number, rev))

def get_specs(commit, specs=None):
    if specs!=None:
        specs_full_path = [os.path.normpath(repo_path+'/'+spec) for spec in specs]
    for group in specs_groups:
        for root, dirs, files in os.walk(repo_path+'/'+group):
            for file in files:
                if file.endswith('.spectra'):
                    full_path = os.path.join(root,file)
                    #print("---full_path: %s" % full_path) 
                    if specs == None or os.path.normpath(full_path) in specs_full_path:
                        folders = []
                        folder = ''
                        path = root
                        while folder != group:
                            path, folder = os.path.split(path)
                            folders = folders + [folder]
                        name = ''
                        for folder in folders:
                            if folder != group:
                                name = folder + '_' + name
                        name = name + os.path.splitext(file)[0]
                        dst_file = specs_path+'/'+group+'/'+name+'_'+str(commit)+'.spectra'
                        #print("dst file: %s" % dst_file)
                        src_file = os.path.normpath(os.path.join(root,file))
                        print("copy from %s to %s" % (src_file, dst_file))
                        copyfile(src_file, dst_file)

def spectra_diff(rev1, rev2):
    summary = client.diff_summarize(repo_path,
                                    revision1=pysvn.Revision(pysvn.opt_revision_kind.number, rev1),
                                    url_or_path2=repo_path,
                                    revision2=pysvn.Revision(pysvn.opt_revision_kind.number, rev2),
                                    recurse=True, ignore_ancestry=True)
    diff = []
    for s in summary:
        if s.path.endswith('.spectra'):
            diff = diff + [s.path]
            
    return diff

def create_specs_from_revisions():
    set_client()
    curr_rev = get_revision()
    diff_rev = curr_rev - 1
    while curr_rev > 1:
        print("current revision = %s" % curr_rev)
        diff = spectra_diff(curr_rev, diff_rev)
        while not diff and diff_rev > 1:
            diff_rev = diff_rev - 1
            diff = spectra_diff(curr_rev, diff_rev)
        commit = diff_rev + 1
        print("found diff spectra files in commit %s" % commit)
        print("diff: %s" % diff)
        get_specs(commit, diff) #was curr_rev
        update_to_rev(diff_rev)
        curr_rev = diff_rev
        diff_rev = diff_rev - 1
        
    
    
